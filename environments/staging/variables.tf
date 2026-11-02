# Declare Staging environment specific variables

variable "project" {
  description = "Project name"
  type        = string
  default     = "saas"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "stg"
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

variable "vpc_cidr_block" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "allowed_ssh_cidr_blocks" {
  description = "CIDR blocks allowed to SSH to EC2 instances. For production, restrict to specific IP ranges or VPN CIDR."
  type        = list(string)
  default     = ["0.0.0.0/0"] # WARNING: Allows SSH from anywhere. Restrict for production!
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3a.small"
}

variable "key_pair_name" {
  description = "Name of the key pair for EC2 instance"
  type        = string
  default     = "saas-stg-server-keypair"
}

# Note: public_key variable removed - key pair must already exist in AWS

variable "s3_bucket_name" {
  description = "Name of the S3 bucket"
  type        = string
  default     = "saas-stg-s3"
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
  description = "PostgreSQL engine version. Use version prefix like '17' for latest 17.x, or specific version like '17.4'"
  type        = string
  default     = "17"
}

variable "db_parameter_group_name" {
  description = "Name of the DB parameter group"
  type        = string
  default     = "default.postgres17"
}

variable "db_allocated_storage" {
  description = "Allocated storage in GB (free tier: 20 GB)"
  type        = number
  default     = 20
}

