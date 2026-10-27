# Input variables for the cloudfront-saas module (CloudFront SaaS Manager foundation).

variable "project" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "aws_region" {
  description = "AWS region for the S3 bucket"
  type        = string
  default     = "eu-north-1"
}

variable "bucket_name" {
  description = "S3 bucket name for the SPA build artifacts"
  type        = string
  default     = "saas-prod-frontend"
}

variable "alb_domain_name" {
  description = "Existing ALB/API hostname used as the custom HTTPS origin for /api/*"
  type        = string
  default     = "api.example.com"
}

variable "og_lambda_qualified_arn" {
  description = "Qualified (versioned) Lambda@Edge ARN for the OG link-preview viewer-request association. Empty = no association."
  type        = string
  default     = ""
}

variable "connection_group_name" {
  description = "CloudFront connection group name (provides the routing endpoint tenants CNAME to)"
  type        = string
  default     = "saas-prod"
}

variable "create_test_tenant" {
  description = "Create one test distribution tenant + its Route53 CNAME to validate the foundation"
  type        = bool
  default     = false
}

variable "test_tenant_domain" {
  description = "Domain for the test distribution tenant (new subdomain)"
  type        = string
  default     = "cf-test.example.com"
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID for the test tenant CNAME (only used when create_test_tenant = true)"
  type        = string
  default     = ""
}

variable "create_app_tenant" {
  description = "Create a distribution tenant for the real app domain (app.example.com). No Route53 change - DNS stays on Amplify."
  type        = bool
  default     = false
}

variable "app_tenant_domain" {
  description = "Domain for the app distribution tenant"
  type        = string
  default     = "app.example.com"
}

