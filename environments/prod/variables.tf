# Production environment variables.
# Scope: Phase 1 (state backend + providers) only. Later phases append their own
# variables to this file as each module is introduced.

variable "project" {
  description = "Project name"
  type        = string
  default     = "saas"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "eu-north-1"
}

variable "aws_profile" {
  description = "AWS profile to use for authentication"
  type        = string
  default     = "terraform-ci"
}

# --- Phase 2: Network ---

variable "vpc_cidr_block" {
  description = "CIDR block for the dedicated prod VPC. Must NOT overlap staging (10.0.0.0/16) or dev (10.1.0.0/16) so future VPC peering stays possible."
  type        = string
  default     = "10.2.0.0/16"
}

variable "create_kms_endpoint" {
  description = "Create the KMS interface VPC endpoint (none exist in the prod VPC yet)"
  type        = bool
  default     = true
}

variable "create_secretsmanager_endpoint" {
  description = "Create the Secrets Manager interface VPC endpoint"
  type        = bool
  default     = true
}

variable "create_ecr_api_endpoint" {
  description = "Create the ECR API interface VPC endpoint"
  type        = bool
  default     = true
}

variable "create_ecr_dkr_endpoint" {
  description = "Create the ECR Docker (dkr) interface VPC endpoint"
  type        = bool
  default     = true
}

variable "create_logs_endpoint" {
  description = "Create the CloudWatch Logs interface VPC endpoint"
  type        = bool
  default     = true
}

variable "create_s3_gateway_endpoint" {
  description = "Create the S3 gateway VPC endpoint (attached to the private route tables)"
  type        = bool
  default     = true
}

variable "vpc_interface_endpoint_subnet_ids" {
  description = "Override subnets for the interface VPC endpoint ENIs. Empty (default) = single AZ: module.network.private_subnet_ids[0] (eu-north-1a)."
  type        = list(string)
  default     = []
}

# --- Phase 3: Security groups ---

variable "container_port" {
  description = "Port the NestJS API container listens on (ALB target + ECS ingress)"
  type        = number
  default     = 3000
}

variable "alb_ingress_cidr_blocks" {
  description = "CIDR blocks allowed to reach the ALB on 443"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# --- Phase 4: Secrets + KMS ---

variable "app_secret_name" {
  description = "Name of the single bundled application secret (JSON bundle of all boot secrets)"
  type        = string
  default     = "saas/prod/app"
}

variable "tenant_secret_prefix" {
  description = "Name prefix for per-tenant secrets the app creates at runtime"
  type        = string
  default     = "tenants/"
}

variable "kms_admin_principal_arns" {
  description = "Additional IAM principal ARNs allowed to ADMINISTER the secrets CMK (cannot Encrypt/Decrypt). Empty = account root only."
  type        = list(string)
  default     = []
}

variable "create_cloudtrail" {
  description = "Create a multi-region management-events CloudTrail (+ S3 + log group) for the human-secret-access alarm. No CloudTrail currently exists in the account."
  type        = bool
  default     = true
}

variable "rds_cloudshell_ingress_security_group_id" {
  description = "SG allowed to reach RDS on 5432 for CloudShell/admin DB access (managed in code). Set null to disable."
  type        = string
  default     = "sg-0xxxxxxxxxxxxxxxx" # cloudshell-db-access (existing)
}

variable "existing_cloudtrail_log_group_name" {
  description = "Attach the secret-access metric filter to this existing CloudTrail log group instead of creating a trail (used only when create_cloudtrail = false)."
  type        = string
  default     = ""
}

# --- Phase 5: Data + buckets ---

variable "db_instance_identifier" {
  description = "Identifier for the prod RDS instance"
  type        = string
  default     = "db-postgresql-saas-prod"
}

variable "db_name" {
  description = "Master/registry database name"
  type        = string
  default     = "saasprodpsqldb"
}

variable "db_username" {
  description = "RDS master username (password managed by RDS in Secrets Manager)"
  type        = string
  default     = "postgres_admin"
}

variable "db_instance_class" {
  description = "RDS instance class (lead-approved db.t4g.small for prod)"
  type        = string
  default     = "db.t4g.small"
}

variable "rds_multi_az" {
  description = "Enable RDS Multi-AZ. False for cost (single-AZ)."
  type        = bool
  default     = false
}

variable "rds_backup_retention_period" {
  description = "RDS automated backup retention in days (>0 enables PITR)"
  type        = number
  default     = 7
}

variable "rds_deletion_protection" {
  description = "Protect the RDS instance from deletion"
  type        = bool
  default     = true
}

variable "redis_node_type" {
  description = "ElastiCache node type (cheap default)"
  type        = string
  default     = "cache.t4g.micro"
}

variable "redis_transit_encryption_enabled" {
  description = "Enable Redis in-transit (TLS) encryption. Must be TRUE to use a Redis AUTH token. Default false (in-transit OFF)."
  type        = bool
  default     = false
}

variable "redis_auth_token" {
  description = "Redis AUTH token (only applied when redis_transit_encryption_enabled = true). Leave null when transit is off."
  type        = string
  default     = null
  sensitive   = true
}

variable "s3_bucket_names" {
  description = "Map of logical key -> S3 bucket name for the three prod buckets"
  type        = map(string)
  default = {
    static_assets  = "saas-prod-static-assets"
    media_assets   = "saas-prod-media-assets"
    knowledge_base = "saas-prod-knowledge-base"
  }
}

# --- Phase 6: ECR + ACM certs ---

variable "route53_zone_name" {
  description = "Public Route 53 hosted zone name for ACM DNS validation and app DNS"
  type        = string
  default     = "example.com"
}

variable "ecr_repository_name" {
  description = "ECR repository name for the API image"
  type        = string
  default     = "saas-prod-api"
}

variable "api_domain_name" {
  description = "API hostname (regional ACM cert for the ALB)"
  type        = string
  default     = "api.example.com"
}

variable "app_domain_name" {
  description = "Frontend hostname (us-east-1 ACM cert for Amplify)"
  type        = string
  default     = "app.example.com"
}

# --- Phase 7: ECS + ALB ---

variable "api_image_tag" {
  description = "Tag of the API image in ECR to deploy"
  type        = string
  default     = "latest"
}

variable "ecs_task_cpu" {
  description = "Fargate task CPU units (2048 = 2 vCPU)"
  type        = number
  default     = 2048
}

variable "ecs_task_memory" {
  description = "Fargate task memory (MiB) (4096 = 4 GB; valid with 2 vCPU)"
  type        = number
  default     = 4096
}

variable "ecs_desired_count" {
  description = "Initial desired task count (0 = nothing runs until migrations are done)"
  type        = number
  default     = 0
}

variable "ecs_min_capacity" {
  description = "Autoscaling minimum task count"
  type        = number
  default     = 0
}

variable "ecs_max_capacity" {
  description = "Autoscaling maximum task count"
  type        = number
  default     = 4
}

variable "ecs_container_insights" {
  description = "ECS cluster Container Insights setting (enabled/disabled)"
  type        = string
  default     = "enabled"
}

variable "ecs_log_retention_days" {
  description = "Retention (days) for the /ecs/saas-prod-api log group"
  type        = number
  default     = 90
}

variable "tenant_domains" {
  description = "Explicit demo/tenant custom domains (hostnames) added to CORS_ORIGIN and (Phase 8) Amplify. No wildcards."
  type        = list(string)
  default     = []
}

variable "autoscaler_exclude_queues" {
  description = "Comma-separated BullMQ queue names the autoscaler excludes from backlog (e.g. the WhatsApp broadcast queue). TODO: set the real queue name."
  type        = string
  default     = ""
}

variable "cloudfront_create_test_tenant" {
  description = "Create one test CloudFront distribution tenant + its Route53 CNAME (cf-test.example.com)"
  type        = bool
  default     = false
}

variable "cloudfront_test_tenant_domain" {
  description = "Domain for the CloudFront test distribution tenant"
  type        = string
  default     = "cf-test.example.com"
}

variable "cloudfront_create_app_tenant" {
  description = "Create a CloudFront distribution tenant for app.example.com (no Route53 change; DNS stays on Amplify)"
  type        = bool
  default     = false
}

variable "container_secrets" {
  description = "Map of ENV_VAR_NAME -> top-level JSON key in the saas/prod/app bundle. Injected via the ECS task-def secrets block. CONFIRM names against the NestJS app + the populated bundle shape."
  type        = map(string)
  # Bundle keys are UPPER_SNAKE and match the env var names exactly. No REDIS_PASSWORD -
  # Redis has no auth, so the app reads process.env.REDIS_PASSWORD as undefined.
  default = {
    DB_USER                        = "DB_USER"
    DB_PASSWORD                    = "DB_PASSWORD"
    AUTH_JWT_PRIVATE_KEY           = "AUTH_JWT_PRIVATE_KEY"
    AUTH_JWT_PUBLIC_KEY            = "AUTH_JWT_PUBLIC_KEY"
    ENCRYPTION_KEY                 = "ENCRYPTION_KEY"
    GOOGLE_KEY                     = "GOOGLE_KEY"
    FACEBOOK_WEBHOOK_VERIFY_TOKEN  = "FACEBOOK_WEBHOOK_VERIFY_TOKEN"
    INSTAGRAM_WEBHOOK_VERIFY_TOKEN = "INSTAGRAM_WEBHOOK_VERIFY_TOKEN"
    SEED_SUPER_ADMIN_PASSWORD      = "SEED_SUPER_ADMIN_PASSWORD"
    SENDGRID_API_KEY               = "SENDGRID_API_KEY"
    INBOUND_EMAIL_SECRET           = "INBOUND_EMAIL_SECRET"
    VAPID_PRIVATE_KEY              = "VAPID_PRIVATE_KEY"
    EXPO_ACCESS_TOKEN              = "EXPO_ACCESS_TOKEN"
    TIKTOK_WEBHOOK_VERIFY_TOKEN    = "TIKTOK_WEBHOOK_VERIFY_TOKEN"
    WHATSAPP_WEBHOOK_VERIFY_TOKEN  = "WHATSAPP_WEBHOOK_VERIFY_TOKEN"
    JWT_ACCESS_TOKEN_EXPIRY        = "JWT_ACCESS_TOKEN_EXPIRY"
    JWT_REFRESH_TOKEN_EXPIRY       = "JWT_REFRESH_TOKEN_EXPIRY"
    JWT_REFRESH_TOKEN_EXPIRY_MS    = "JWT_REFRESH_TOKEN_EXPIRY_MS"
    AWS_TENANT_SECRETS_KMS_KEY_ID  = "AWS_TENANT_SECRETS_KMS_KEY_ID"
    SENDGRID_FROM_EMAIL            = "SENDGRID_FROM_EMAIL"
    INBOUND_EMAIL_DOMAIN           = "INBOUND_EMAIL_DOMAIN"
    TENANT_DELETION_RETENTION_DAYS = "TENANT_DELETION_RETENTION_DAYS"
    VAPID_PUBLIC_KEY               = "VAPID_PUBLIC_KEY"
    VAPID_SUBJECT                  = "VAPID_SUBJECT"
    VITE_VAPID_PUBLIC_KEY          = "VITE_VAPID_PUBLIC_KEY"
    APP_ROOT_DOMAINS               = "APP_ROOT_DOMAINS"
    # Added by dev in the app-secret bundle (Intercom integration + embedded-mode flag).
    EMBEDDED_TEST            = "EMBEDDED_TEST"
    VITE_INTERCOM_APP_ID     = "VITE_INTERCOM_APP_ID"
    INTERCOM_IDENTITY_SECRET = "INTERCOM_IDENTITY_SECRET"
  }
}

# --- Phase 8: Amplify (web frontend) ---

variable "amplify_app_name" {
  description = "Amplify app name"
  type        = string
  default     = "saas-prod-web"
}

variable "amplify_repository" {
  description = "GitHub repository URL for the web frontend"
  type        = string
  default     = "https://github.com/your-org/saas-app"
}

variable "amplify_branch_name" {
  description = "Git branch Amplify tracks"
  type        = string
  default     = "prod"
}

variable "github_access_token" {
  description = "GitHub personal access token for Amplify to connect the repo. Supply via prod.tfvars (gitignored) or TF_VAR_github_access_token - never commit it."
  type        = string
  sensitive   = true
}

variable "amplify_enable_custom_domain" {
  description = "Create the Amplify custom domain association for example.com (app + wildcard)"
  type        = bool
  default     = true
}

variable "amplify_subdomain_prefixes" {
  description = "Amplify subdomain prefixes -> prod branch. Only 'app'; the Amplify-managed cert still covers *.example.com."
  type        = list(string)
  default     = ["app"]
}

variable "amplify_custom_domains" {
  description = "Per-tenant custom root domains for Amplify. Key = root domain, value.prefix = subdomain. e.g. { \"acme.com\" = { prefix = \"crm\" } }"
  type        = map(object({ prefix = string }))
  default     = {}
}

# --- Temporary: SSM bastion for one-time DB bootstrap (destroy after use) ---

variable "create_bastion" {
  description = "Create a TEMPORARY SSM-managed bastion in a private subnet for one-time DB bootstrap. Set false (and apply) to destroy it afterwards."
  type        = bool
  default     = false
}

variable "alerts_slack_team_id" {
  description = "Slack workspace (team) ID for the ops-alerts Chatbot channel."
  type        = string
  default     = "T02MYPPL656"
}

variable "alerts_slack_channel_id" {
  description = "Slack channel ID for the ops-alerts Chatbot channel (#saas-prod-alerts)."
  type        = string
  default     = "C0BJUH8CJ9M"
}
