# Production environment - core resources.
# Built phase by phase; each phase appends its module block(s) here.

# ---------------------------------------------------------------------------
# Phase 2: Network (dedicated prod VPC) + VPC endpoints
# ---------------------------------------------------------------------------

# Dedicated prod VPC - mirrors the staging/dev layout (2 public + 2 private subnets
# across 2 AZs) via the shared network module, but with:
#   - nat_per_az = false                 -> single shared NAT Gateway (cost; lead-approved)
#   - create_default_security_groups=false -> prod defines its own SGs (Phase 3)
module "network" {
  source = "../../modules/network"

  project        = var.project
  environment    = var.environment
  aws_region     = var.aws_region
  vpc_cidr_block = var.vpc_cidr_block

  nat_per_az                     = false
  create_default_security_groups = false
}

# Interface + gateway VPC endpoints in the prod VPC's private subnets.
# Required for the Phase-4 KMS aws:SourceVpce binding.
module "vpc_endpoints" {
  source = "../../modules/vpc-endpoints"

  project        = var.project
  environment    = var.environment
  aws_region     = var.aws_region
  vpc_id         = module.network.vpc_id
  vpc_cidr_block = module.network.vpc_cidr_block

  private_subnet_ids      = module.network.private_subnet_ids
  private_route_table_ids = module.network.private_route_table_ids

  # Single-AZ interface endpoints: override list if given, else the first private
  # subnet (eu-north-1a, where RDS lives).
  interface_endpoint_subnet_ids = length(var.vpc_interface_endpoint_subnet_ids) > 0 ? var.vpc_interface_endpoint_subnet_ids : [module.network.private_subnet_ids[0]]

  create_kms_endpoint            = var.create_kms_endpoint
  create_secretsmanager_endpoint = var.create_secretsmanager_endpoint
  create_ecr_api_endpoint        = var.create_ecr_api_endpoint
  create_ecr_dkr_endpoint        = var.create_ecr_dkr_endpoint
  create_logs_endpoint           = var.create_logs_endpoint
  create_s3_gateway_endpoint     = var.create_s3_gateway_endpoint
}

# ---------------------------------------------------------------------------
# Phase 3: Security groups (prod ECS/ALB chain)
# ---------------------------------------------------------------------------

# ALB -> ECS -> RDS / Redis least-privilege chain, separate from the Phase-2
# interface-endpoint SG.
module "security_groups" {
  source = "../../modules/security-groups"

  project        = var.project
  environment    = var.environment
  aws_region     = var.aws_region
  vpc_id         = module.network.vpc_id
  container_port = var.container_port

  alb_ingress_cidr_blocks = var.alb_ingress_cidr_blocks

  # Allow the worker SG + autoscaler Lambda SG to reach Redis on 6379 (inline rules).
  worker_security_group_id     = aws_security_group.worker.id
  autoscaler_security_group_id = aws_security_group.autoscaler_lambda.id

  # Allow the CloudShell/admin SG to reach RDS on 5432 (managed in code, not drift).
  rds_cloudshell_ingress_security_group_id = var.rds_cloudshell_ingress_security_group_id
}

# ---------------------------------------------------------------------------
# Phase 4: Secrets + KMS (three-gate model)
# ---------------------------------------------------------------------------

# Customer-managed KMS key, ECS execution + task roles, and the empty boot-secret
# containers. Key usage is bound to the KMS + Secrets Manager VPC endpoints.
module "secrets" {
  source = "../../modules/secrets"

  project     = var.project
  environment = var.environment
  aws_region  = var.aws_region

  kms_vpc_endpoint_id            = module.vpc_endpoints.interface_endpoint_ids["kms"]
  secretsmanager_vpc_endpoint_id = module.vpc_endpoints.interface_endpoint_ids["secretsmanager"]

  app_secret_name          = var.app_secret_name
  tenant_secret_prefix     = var.tenant_secret_prefix
  kms_admin_principal_arns = var.kms_admin_principal_arns

  # Phase 5: let RDS + ElastiCache use the CMK for storage encryption (via service).
  aws_service_via_services = [
    "rds.${var.aws_region}.amazonaws.com",
    "elasticache.${var.aws_region}.amazonaws.com",
  ]
}

# CloudTrail -> CloudWatch Logs + metric filter + alarm (SNS) for human secret reads.
module "secret_access_audit" {
  source = "../../modules/secret-access-audit"

  project     = var.project
  environment = var.environment
  aws_region  = var.aws_region

  create_cloudtrail                  = var.create_cloudtrail
  existing_cloudtrail_log_group_name = var.existing_cloudtrail_log_group_name
}

# Central ops alerts: one SNS topic -> email (manual subs) + Slack via AWS Chatbot.
# Chatbot also forwards the existing secret-access topic to the same Slack channel.
module "ops_alerts" {
  source = "../../modules/ops-alerts"

  project     = var.project
  environment = var.environment

  slack_team_id    = var.alerts_slack_team_id
  slack_channel_id = var.alerts_slack_channel_id

  extra_sns_topic_arns = [module.secret_access_audit.sns_topic_arn]
}

# CloudWatch alarms (ALB/API, ECS, RDS, Redis, Lambda) -> central alerts topic.
module "monitoring" {
  source = "../../modules/monitoring"

  project     = var.project
  environment = var.environment

  # Alarms publish to the RAW topic; the formatter Lambda rewrites them into
  # plain language and republishes to the clean topic (email + Slack).
  alarms_topic_arn = module.ops_alerts.raw_topic_arn

  alb_arn_suffix          = module.ecs.alb_arn_suffix
  target_group_arn_suffix = module.ecs.target_group_arn_suffix
  ecs_cluster_name        = module.ecs.cluster_name
  ecs_service_name        = module.ecs.service_name
  rds_instance_id         = module.rds.rds_instance_id
  redis_node_id           = "${module.cache.redis_replication_group_id}-001"

  lambda_function_names = {
    worker-autoscaler = module.worker_autoscaler.lambda_function_name
    secret-notifier   = module.secret_access_audit.secret_access_notifier_lambda_name
  }
}

# ---------------------------------------------------------------------------
# Phase 5: Data + buckets
# ---------------------------------------------------------------------------

# Master/registry PostgreSQL (single-AZ for cost; backups + PITR + deletion
# protection + CMK-encrypted). Per-tenant DBs are created at runtime by the app.
module "rds" {
  source = "../../modules/rds"

  project     = var.project
  environment = var.environment
  aws_region  = var.aws_region

  private_subnet_ids    = module.network.private_subnet_ids
  rds_security_group_id = module.security_groups.rds_security_group_id
  kms_key_id            = module.secrets.kms_key_arn

  db_instance_identifier  = var.db_instance_identifier
  db_name                 = var.db_name
  db_username             = var.db_username
  db_instance_class       = var.db_instance_class
  multi_az                = var.rds_multi_az
  backup_retention_period = var.rds_backup_retention_period
  deletion_protection     = var.rds_deletion_protection
}

# ElastiCache Redis (single node, non-cluster, CMK at-rest; in-transit/auth optional).
module "cache" {
  source = "../../modules/cache"

  project     = var.project
  environment = var.environment
  aws_region  = var.aws_region

  private_subnet_ids      = module.network.private_subnet_ids
  redis_security_group_id = module.security_groups.redis_security_group_id
  kms_key_arn             = module.secrets.kms_key_arn

  node_type                  = var.redis_node_type
  transit_encryption_enabled = var.redis_transit_encryption_enabled
  auth_token                 = var.redis_auth_token

  # Custom parameter group: maxmemory-policy = noeviction (family redis7).
  create_parameter_group = true
  parameter_group_family = "redis7"
  maxmemory_policy       = "noeviction"
}

# Three prod S3 buckets + the S3 access policy on the existing ECS task role.
module "storage" {
  source = "../../modules/storage"

  project     = var.project
  environment = var.environment
  aws_region  = var.aws_region

  bucket_names   = var.s3_bucket_names
  task_role_name = module.secrets.task_role_name
  task_role_arn  = module.secrets.task_role_arn

  # CORS adopted from the dev's manual CLI change (browser direct upload/download).
  # static_assets is limited to the app's own subdomains; media/knowledge also allow
  # the CRM origins. Values mirror live exactly to keep the plan a no-op after apply.
  cors_rules = {
    static_assets = {
      allowed_headers = ["*"]
      allowed_methods = ["PUT", "GET", "HEAD"]
      allowed_origins = ["*.example.com"]
      expose_headers  = ["ETag"]
      max_age_seconds = 3000
    }
    media_assets = {
      allowed_headers = ["*"]
      allowed_methods = ["PUT", "GET", "HEAD"]
      allowed_origins = ["*.example.com", "*crm.example.com", "*crm.example.net"]
      expose_headers  = ["ETag"]
      max_age_seconds = 3000
    }
    knowledge_base = {
      allowed_headers = ["*"]
      allowed_methods = ["PUT", "GET", "HEAD"]
      allowed_origins = ["*.example.com", "*crm.example.com", "*crm.example.net"]
      expose_headers  = ["ETag"]
      max_age_seconds = 3000
    }
  }
}

# ---------------------------------------------------------------------------
# Phase 6: ECR + ACM certificates
# ---------------------------------------------------------------------------

# Hosted zone for example.com (public) - validation records land here.
data "aws_route53_zone" "main" {
  name         = var.route53_zone_name
  private_zone = false
}

# ECR repository for the API image (pushed manually / by CI).
module "ecr" {
  source = "../../modules/ecr"

  project         = var.project
  environment     = var.environment
  aws_region      = var.aws_region
  repository_name = var.ecr_repository_name
}

# Regional cert (eu-north-1) for the ALB - api.example.com.
module "acm_api" {
  source = "../../modules/acm"

  project         = var.project
  environment     = var.environment
  domain_name     = var.api_domain_name
  route53_zone_id = data.aws_route53_zone.main.zone_id
}

# us-east-1 cert for Amplify - app.example.com (via the aliased provider).
module "acm_app" {
  source = "../../modules/acm"
  providers = {
    aws = aws.us_east_1
  }

  project         = var.project
  environment     = var.environment
  domain_name     = var.app_domain_name
  route53_zone_id = data.aws_route53_zone.main.zone_id
}

# Wildcard cert for *.example.com (us-east-1, for CloudFront SaaS tenant subdomains).
# DNS-validated; NO wildcard routing record is created - routing stays per-tenant.
module "acm_wildcard" {
  source = "../../modules/acm"
  providers = {
    aws = aws.us_east_1
  }

  project         = var.project
  environment     = var.environment
  domain_name     = "*.${var.route53_zone_name}"
  route53_zone_id = data.aws_route53_zone.main.zone_id
}

# ---------------------------------------------------------------------------
# Phase 7: ECS + ALB
# ---------------------------------------------------------------------------

module "ecs" {
  source = "../../modules/ecs"

  project     = var.project
  environment = var.environment
  aws_region  = var.aws_region

  vpc_id                = module.network.vpc_id
  public_subnet_ids     = module.network.public_subnet_ids
  private_subnet_ids    = module.network.private_subnet_ids
  alb_security_group_id = module.security_groups.alb_security_group_id
  ecs_security_group_id = module.security_groups.ecs_security_group_id
  certificate_arn       = module.acm_api.certificate_arn

  # Pin the ECS service to AZ-a only (ALB still spans both public subnets).
  service_subnet_ids = [module.network.private_subnet_ids[0]]

  container_image    = "${module.ecr.repository_url}:${var.api_image_tag}"
  container_port     = var.container_port
  task_cpu           = var.ecs_task_cpu
  task_memory        = var.ecs_task_memory
  execution_role_arn = module.secrets.execution_role_arn
  task_role_arn      = module.secrets.task_role_arn

  # API task connects to the DB through the RDS Proxy (migration stays on direct RDS).
  db_host = module.rds.rds_address

  # Worker tier (same image, PROCESS_ROLE=worker, AZ-a only, no load balancer).
  enable_worker            = true
  worker_security_group_id = aws_security_group.worker.id
  worker_subnet_ids        = [module.network.private_subnet_ids[0]]

  desired_count      = var.ecs_desired_count
  min_capacity       = var.ecs_min_capacity
  max_capacity       = var.ecs_max_capacity
  app_secret_arn     = module.secrets.app_secret_arn
  container_secrets  = var.container_secrets
  container_insights = var.ecs_container_insights
  log_retention_days = var.ecs_log_retention_days

  # Plain (non-sensitive) environment. AWS_ENDPOINT_URL / AWS_ACCESS_KEY_ID /
  # AWS_SECRET_ACCESS_KEY / COOKIE_DOMAIN are intentionally UNSET (task role provides
  # AWS creds; the refresh cookie binds to the request origin).
  plain_environment = {
    NODE_ENV                     = "production"
    APP_DEPLOYMENT               = "production"
    APP_API_URL                  = "https://${var.api_domain_name}"
    MODE                         = "notdemo"
    APP_PORT                     = "3000"
    APP_NAME                     = "SaaS"
    AUTO_SEED                    = "true"
    SKIP_MIGRATIONS              = "false"
    DB_HOST                      = module.rds.rds_address
    DB_PORT                      = "5432"
    DB_NAME                      = var.db_name
    DB_SSL                       = "true"
    REDIS_HOST                   = module.cache.redis_primary_endpoint
    REDIS_PORT                   = "6379"
    AWS_S3_STATIC_ASSETS_BUCKET  = module.storage.static_assets_bucket
    AWS_S3_INTERIM_MEDIA_BUCKET  = module.storage.media_assets_bucket
    AWS_S3_KNOWLEDGE_BASE_BUCKET = module.storage.knowledge_base_bucket
    AWS_REGION                   = var.aws_region
    FRONTEND_URL                 = "https://${var.app_domain_name}"
    CORS_ORIGIN = join(",", concat(
      ["https://${var.app_domain_name}"],
      [for d in var.tenant_domains : "https://${d}"]
    ))

    # TODO: replace this placeholder with a real prod value before go-live.
    AD_DEFAULT_URL = "PLACEHOLDER_AD_DEFAULT_URL"
  }
}

# RDS Proxy removed - the app connects directly to RDS (module.rds).

# ---------------------------------------------------------------------------
# Worker autoscaler (Lambda + 1-min EventBridge Scheduler on BullMQ queue depth)
# ---------------------------------------------------------------------------

module "worker_autoscaler" {
  source = "../../modules/worker-autoscaler"

  project     = var.project
  environment = var.environment
  aws_region  = var.aws_region

  subnet_ids         = [module.network.private_subnet_ids[0]] # AZ-a
  security_group_ids = [aws_security_group.autoscaler_lambda.id]
  redis_host         = module.cache.redis_primary_endpoint

  cluster_name   = module.ecs.cluster_name
  service_name   = module.ecs.worker_service_name
  exclude_queues = var.autoscaler_exclude_queues

  # Settle worker toward 1 when the queue is idle, up to 4 under load.
  n_min = 1
  n_max = 4
}

# ---------------------------------------------------------------------------
# Lambda@Edge OG link-preview function (us-east-1, for the SaaS distribution)
# ---------------------------------------------------------------------------

module "lambda_edge_og" {
  source = "../../modules/lambda-edge-og"
  providers = {
    aws = aws.us_east_1
  }

  project     = var.project
  environment = var.environment
}

# ---------------------------------------------------------------------------
# CloudFront SaaS Manager foundation (alongside Amplify; no DNS/Amplify/ALB changes)
# ---------------------------------------------------------------------------

module "cloudfront_saas" {
  source = "../../modules/cloudfront-saas"

  project         = var.project
  environment     = var.environment
  aws_region      = var.aws_region
  alb_domain_name = var.api_domain_name

  # Lambda@Edge OG link-preview on the default behavior (versioned ARN).
  og_lambda_qualified_arn = module.lambda_edge_og.lambda_edge_og_qualified_arn

  create_test_tenant = var.cloudfront_create_test_tenant
  test_tenant_domain = var.cloudfront_test_tenant_domain
  route53_zone_id    = data.aws_route53_zone.main.zone_id

  create_app_tenant = var.cloudfront_create_app_tenant
  app_tenant_domain = var.app_domain_name
}

# ---------------------------------------------------------------------------
# GitHub Actions CI IAM user (access-key based; no OIDC)
# ---------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

module "github_ci_user" {
  source = "../../modules/github-ci-user"

  project     = var.project
  environment = var.environment

  ecr_repository_arn = module.ecr.repository_arn
  ecs_service_arns = [
    "arn:aws:ecs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:service/${module.ecs.cluster_name}/${module.ecs.service_name}",
    "arn:aws:ecs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:service/${module.ecs.cluster_name}/${module.ecs.worker_service_name}",
  ]
  frontend_bucket_arn                = "arn:aws:s3:::${module.cloudfront_saas.frontend_bucket_name}"
  cloudfront_distribution_arn        = "arn:aws:cloudfront::${data.aws_caller_identity.current.account_id}:distribution/${module.cloudfront_saas.distribution_id}"
  cloudfront_distribution_tenant_arn = "arn:aws:cloudfront::${data.aws_caller_identity.current.account_id}:distribution-tenant/*"
}

# NOTE: the SPA Amplify app (module "amplify") was retired - the SPA is served by the
# CloudFront SaaS multitenant distribution. modules/amplify/ is left in place (unused).

# api.example.com -> ALB (A alias)
resource "aws_route53_record" "api" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.api_domain_name
  type    = "A"

  alias {
    name                   = module.ecs.alb_dns_name
    zone_id                = module.ecs.alb_zone_id
    evaluate_target_health = true
  }
}
