# Input variables for the rds-proxy module.

variable "project" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-north-1"
}

variable "vpc_id" {
  description = "VPC ID for the proxy security group"
  type        = string
}

variable "subnet_ids" {
  description = "Subnets for the RDS Proxy. RDS Proxy REQUIRES at least 2 subnets across 2 AZs, so this is both private subnets (cannot be pinned to a single AZ)."
  type        = list(string)
}

variable "ecs_security_group_id" {
  description = "ECS task security group ID allowed to reach the proxy on 5432. Passed as a literal to avoid a module dependency cycle with the security-groups module."
  type        = string
  default     = "sg-0xxxxxxxxxxxxxxxx"
}

variable "db_instance_identifier" {
  description = "Identifier of the RDS instance the proxy targets"
  type        = string
  default     = "db-postgresql-saas-prod"
}

variable "kms_key_arn" {
  description = "Customer-managed KMS key ARN to encrypt the new proxy secret"
  type        = string
}

variable "app_secret_name" {
  description = "Name of the existing bundled app secret to read the app DB creds from"
  type        = string
  default     = "saas/prod/app"
}

variable "app_secret_username_key" {
  description = "JSON key in the bundle holding the app DB username"
  type        = string
  default     = "DB_USER"
}

variable "app_secret_password_key" {
  description = "JSON key in the bundle holding the app DB password"
  type        = string
  default     = "DB_PASSWORD"
}

variable "proxy_secret_name" {
  description = "Name of the new dedicated proxy secret ({username, password})"
  type        = string
  default     = "saas/prod/proxy-saas_app"
}

variable "require_tls" {
  description = "Require TLS for client connections to the proxy"
  type        = bool
  default     = true
}

variable "worker_security_group_id" {
  description = "If set, add an inline ingress on the proxy SG allowing 5432 from the worker SG."
  type        = string
  default     = null
}
