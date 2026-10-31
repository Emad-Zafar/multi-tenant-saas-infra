# Production environment outputs.
# Built phase by phase; each phase appends its outputs here.

# --- Phase 2: Network ---

output "vpc_id" {
  description = "ID of the prod VPC"
  value       = module.network.vpc_id
}

output "vpc_cidr_block" {
  description = "CIDR block of the prod VPC"
  value       = module.network.vpc_cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.network.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = module.network.private_subnet_ids
}

output "nat_gateway_ids" {
  description = "IDs of the NAT gateways (one per AZ)"
  value       = module.network.nat_gateway_ids
}

output "private_route_table_ids" {
  description = "IDs of the private route tables (one per AZ)"
  value       = module.network.private_route_table_ids
}

# --- Phase 2: VPC endpoints ---

output "vpc_interface_endpoint_ids" {
  description = "Map of interface VPC endpoint name -> ID"
  value       = module.vpc_endpoints.interface_endpoint_ids
}

output "vpc_s3_gateway_endpoint_id" {
  description = "ID of the S3 gateway VPC endpoint"
  value       = module.vpc_endpoints.s3_gateway_endpoint_id
}

# --- Phase 3: Security groups ---

output "alb_security_group_id" {
  description = "ID of the ALB security group"
  value       = module.security_groups.alb_security_group_id
}

output "ecs_security_group_id" {
  description = "ID of the ECS task security group"
  value       = module.security_groups.ecs_security_group_id
}

output "rds_security_group_id" {
  description = "ID of the RDS security group"
  value       = module.security_groups.rds_security_group_id
}

output "redis_security_group_id" {
  description = "ID of the Redis security group"
  value       = module.security_groups.redis_security_group_id
}

# --- Phase 4: Secrets + KMS ---

output "kms_key_arn" {
  description = "ARN of the customer-managed secrets KMS key"
  value       = module.secrets.kms_key_arn
}

output "ecs_execution_role_arn" {
  description = "ARN of the ECS task execution role"
  value       = module.secrets.execution_role_arn
}

output "ecs_task_role_arn" {
  description = "ARN of the ECS task (runtime app identity) role"
  value       = module.secrets.task_role_arn
}

output "app_secret_arn" {
  description = "ARN of the bundled application secret"
  value       = module.secrets.app_secret_arn
}

output "secret_access_alarm_sns_topic_arn" {
  description = "SNS topic ARN for the human-secret-access alarm"
  value       = module.secret_access_audit.sns_topic_arn
}

# --- Phase 5: Data + buckets ---

output "rds_endpoint" {
  description = "RDS endpoint (host:port)"
  value       = module.rds.rds_endpoint
}

output "rds_address" {
  description = "RDS hostname (DB_HOST)"
  value       = module.rds.rds_address
}

output "rds_master_user_secret_arn" {
  description = "ARN of the RDS-managed master user secret (Secrets Manager)"
  value       = module.rds.rds_master_user_secret_arn
}

output "redis_primary_endpoint" {
  description = "Redis primary endpoint (REDIS_HOST)"
  value       = module.cache.redis_primary_endpoint
}

output "worker_service_name" {
  description = "Worker ECS service name"
  value       = module.ecs.worker_service_name
}

output "worker_autoscaler_lambda_name" {
  description = "Worker-autoscaler Lambda function name"
  value       = module.worker_autoscaler.lambda_function_name
}

# --- CloudFront SaaS ---

output "cloudfront_saas_bucket" {
  description = "Frontend S3 bucket for the CloudFront SaaS distribution"
  value       = module.cloudfront_saas.frontend_bucket_name
}

output "cloudfront_saas_distribution_id" {
  description = "Multi-tenant CloudFront distribution ID"
  value       = module.cloudfront_saas.distribution_id
}

output "cloudfront_saas_routing_endpoint" {
  description = "Connection group routing endpoint (tenant CNAME target)"
  value       = module.cloudfront_saas.connection_group_routing_endpoint
}

output "cloudfront_saas_test_tenant_domain" {
  description = "Domain of the CloudFront test distribution tenant (null if not created)"
  value       = module.cloudfront_saas.test_tenant_domain
}

output "cloudfront_saas_app_tenant_id" {
  description = "ID of the app.example.com CloudFront distribution tenant (null if not created)"
  value       = module.cloudfront_saas.app_tenant_id
}

output "cloudfront_saas_app_tenant_routing_endpoint" {
  description = "Routing endpoint to CNAME app.example.com to when cutting over from Amplify"
  value       = module.cloudfront_saas.app_tenant_routing_endpoint
}

# --- GitHub CI user ---

output "github_ci_access_key_id" {
  description = "Access key ID for the GitHub Actions CI user"
  value       = module.github_ci_user.access_key_id
}

output "github_ci_secret_access_key" {
  description = "Secret access key for the GitHub Actions CI user"
  value       = module.github_ci_user.secret_access_key
  sensitive   = true
}

output "s3_static_assets_bucket" {
  description = "AWS_S3_STATIC_ASSETS_BUCKET"
  value       = module.storage.static_assets_bucket
}

output "s3_interim_media_bucket" {
  description = "AWS_S3_INTERIM_MEDIA_BUCKET"
  value       = module.storage.media_assets_bucket
}

output "s3_knowledge_base_bucket" {
  description = "AWS_S3_KNOWLEDGE_BASE_BUCKET"
  value       = module.storage.knowledge_base_bucket
}

# --- Phase 6: ECR + ACM certs ---

output "ecr_repository_url" {
  description = "ECR repository URL for the API image"
  value       = module.ecr.repository_url
}

output "acm_api_certificate_arn" {
  description = "Regional ACM cert ARN for api.example.com (ALB)"
  value       = module.acm_api.certificate_arn
}

output "acm_app_certificate_arn" {
  description = "us-east-1 ACM cert ARN for app.example.com (Amplify)"
  value       = module.acm_app.certificate_arn
}

output "wildcard_cert_arn" {
  description = "us-east-1 wildcard ACM cert ARN for *.example.com (CloudFront SaaS tenants)"
  value       = module.acm_wildcard.certificate_arn
}

# --- Phase 7: ECS + ALB ---

output "alb_dns_name" {
  description = "ALB DNS name"
  value       = module.ecs.alb_dns_name
}

output "api_hostname" {
  description = "Public API hostname (Route 53 alias -> ALB)"
  value       = var.api_domain_name
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = module.ecs.cluster_name
}

output "ecs_service_name" {
  description = "ECS service name"
  value       = module.ecs.service_name
}

output "migration_task_definition_arn" {
  description = "One-off migration task definition ARN"
  value       = module.ecs.migration_task_definition_arn
}

# (Amplify SPA app retired - outputs removed along with module "amplify".)

# --- Ops alerts ---
output "alerts_topic_arn" {
  description = "Central alerts SNS topic (email subs added manually; also feeds Slack)"
  value       = module.ops_alerts.alerts_topic_arn
}

output "alerts_chatbot_configuration_arn" {
  description = "AWS Chatbot Slack channel configuration ARN"
  value       = module.ops_alerts.chatbot_configuration_arn
}
