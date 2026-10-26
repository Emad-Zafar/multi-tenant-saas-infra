# Input variables for the github-ci-user module (prod GitHub Actions IAM user).

variable "project" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "user_name" {
  description = "IAM user name for the GitHub Actions CI pipeline"
  type        = string
  default     = "saas-prod-github-ci"
}

variable "ecr_repository_arn" {
  description = "ARN of the ECR repository the pipeline pushes to"
  type        = string
}

variable "ecs_service_arns" {
  description = "ECS service ARNs the pipeline may update (api + worker)"
  type        = list(string)
}

variable "frontend_bucket_arn" {
  description = "ARN of the frontend S3 bucket the pipeline syncs to"
  type        = string
}

variable "cloudfront_distribution_arn" {
  description = "ARN of the CloudFront distribution the pipeline invalidates"
  type        = string
}

variable "cloudfront_distribution_tenant_arn" {
  description = "ARN (or wildcard pattern) of CloudFront distribution tenants the pipeline invalidates"
  type        = string
}
