# Input variables for the RDS module (prod master/registry PostgreSQL).

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
  description = "Private subnet IDs for the DB subnet group"
  type        = list(string)
}

variable "rds_security_group_id" {
  description = "ID of the RDS security group (PostgreSQL from ECS only)"
  type        = string
}

variable "kms_key_id" {
  description = "ARN of the customer-managed KMS key for storage + master-user-secret encryption"
  type        = string
}

variable "db_instance_identifier" {
  description = "Identifier for the RDS instance"
  type        = string
  default     = "db-postgresql-saas-prod"
}

variable "db_name" {
  description = "Name of the master/registry database created by RDS"
  type        = string
  default     = "saasprodpsqldb"
}

variable "db_username" {
  description = "Master username (password is managed by RDS in Secrets Manager)"
  type        = string
  default     = "postgres_admin"
}

variable "db_instance_class" {
  description = "RDS instance class (cheap ARM-based default)"
  type        = string
  default     = "db.t4g.micro"
}

variable "db_engine_version" {
  description = "PostgreSQL engine version (prefix like '17' = latest 17.x)"
  type        = string
  default     = "17"
}

variable "db_parameter_group_name" {
  description = "DB parameter group name"
  type        = string
  default     = "default.postgres17"
}

variable "db_allocated_storage" {
  description = "Allocated storage in GB"
  type        = number
  default     = 20
}

variable "db_max_allocated_storage" {
  description = "Max storage for autoscaling in GB"
  type        = number
  default     = 100
}

variable "multi_az" {
  description = "Enable Multi-AZ. False for prod here (cost) - single-AZ."
  type        = bool
  default     = false
}

variable "backup_retention_period" {
  description = "Days of automated backups (>0 enables point-in-time recovery)"
  type        = number
  default     = 7
}

variable "backup_window" {
  description = "Daily backup window (UTC)"
  type        = string
  default     = "03:00-04:00"
}

variable "maintenance_window" {
  description = "Weekly maintenance window (UTC)"
  type        = string
  default     = "mon:04:00-mon:05:00"
}

variable "deletion_protection" {
  description = "Protect the instance from deletion"
  type        = bool
  default     = true
}
