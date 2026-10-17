# Input variables for IAM module

variable "project" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "eu-north-1"
}

variable "s3_bucket_arn" {
  description = "ARN of the S3 bucket for IAM policies"
  type        = string
}

variable "create_app_user_access_key" {
  description = "Whether to create access keys for application user"
  type        = bool
  default     = false
}

variable "create_devops_user_access_key" {
  description = "Whether to create access keys for DevOps user"
  type        = bool
  default     = false
}

