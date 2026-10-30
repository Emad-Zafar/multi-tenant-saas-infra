# Input variables for the Secret-Access Audit module.
# Creates the CloudTrail -> CloudWatch Logs pipeline (none exists in the account yet)
# and a metric filter + alarm that fires when a HUMAN IAM user reads a secret.

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

variable "create_cloudtrail" {
  description = "Create a multi-region management-events CloudTrail (+ S3 bucket + CloudWatch Logs group). Set false to attach the metric filter to an existing trail's log group instead."
  type        = bool
  default     = true
}

variable "existing_cloudtrail_log_group_name" {
  description = "Name of an existing CloudTrail CloudWatch Logs group to attach the metric filter to (used only when create_cloudtrail = false)."
  type        = string
  default     = ""
}

variable "log_retention_days" {
  description = "Retention (days) for the CloudTrail CloudWatch Logs group when created."
  type        = number
  default     = 90
}

