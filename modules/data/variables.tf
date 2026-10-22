# Input variables for Data module

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

variable "private_subnet_ids" {
  description = "List of private subnet IDs for RDS placement"
  type        = list(string)
}

variable "rds_security_group_id" {
  description = "ID of the RDS security group"
  type        = string
}

variable "ec2_iam_role_arn" {
  description = "ARN of the IAM role attached to EC2 instance for S3 access. This is required and provided by the IAM module."
  type        = string
  # No default - must be provided since IAM role is always created
}

variable "s3_bucket_name" {
  description = "Name of the S3 bucket"
  type        = string
}

# RDS Variables
variable "db_instance_identifier" {
  description = "Identifier for the RDS instance"
  type        = string
  default     = "db-postgresql-saas-stg"
}

variable "db_name" {
  description = "Name of the database"
  type        = string
  default     = "saas-stg-psql-db"
}

variable "db_username" {
  description = "Master username for the database"
  type        = string
  default     = "postgres-admin"
}

variable "db_instance_class" {
  description = "Instance class for RDS (db-t4g.micro for ARM-based, cost-effective)"
  type        = string
  default     = "db.t4g.micro"
}

variable "db_engine_version" {
  description = "PostgreSQL engine version. Use version prefix like '17' for latest 17.x, or specific version like '17.4'. AWS will use the latest available version matching the prefix. Available versions vary by region."
  type        = string
  default     = "17" # AWS will use the latest 17.x version available in the region
}

variable "db_parameter_group_name" {
  description = "Name of the DB parameter group"
  type        = string
  default     = "default.postgres17"
}

variable "kms_key_id" {
  description = "KMS key ID for encrypting the master user secret. If not specified, uses the default AWS managed key"
  type        = string
  default     = null
}

variable "db_allocated_storage" {
  description = "Allocated storage in GB (free tier: 20 GB)"
  type        = number
  default     = 20
}

variable "db_max_allocated_storage" {
  description = "Maximum allocated storage for autoscaling"
  type        = number
  default     = 100
}

variable "skip_final_snapshot" {
  description = "Whether to skip final snapshot when deleting the database"
  type        = bool
  default     = true
}

