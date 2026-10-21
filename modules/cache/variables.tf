# Input variables for the ElastiCache Redis module (prod, single node, non-cluster).

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
  description = "Private subnet IDs for the cache subnet group"
  type        = list(string)
}

variable "redis_security_group_id" {
  description = "ID of the Redis security group (6379 from ECS only)"
  type        = string
}

variable "kms_key_arn" {
  description = "ARN of the customer-managed KMS key for at-rest encryption"
  type        = string
}

variable "node_type" {
  description = "ElastiCache node type (cheap default)"
  type        = string
  default     = "cache.t4g.micro"
}

variable "engine_version" {
  description = "Redis engine version"
  type        = string
  default     = "7.1"
}

variable "parameter_group_name" {
  description = "Redis parameter group to use when create_parameter_group = false"
  type        = string
  default     = "default.redis7"
}

variable "create_parameter_group" {
  description = "Create a custom ElastiCache parameter group and attach it to the replication group"
  type        = bool
  default     = false
}

variable "parameter_group_family" {
  description = "Parameter group family (must match the engine version, e.g. redis7)"
  type        = string
  default     = "redis7"
}

variable "maxmemory_policy" {
  description = "Redis maxmemory-policy eviction setting"
  type        = string
  default     = "noeviction"
}

variable "transit_encryption_enabled" {
  description = "Enable in-transit (TLS) encryption. NOTE: ElastiCache requires this to be TRUE to set auth_token. Default false (in-transit OFF) per the cost/simplicity decision."
  type        = bool
  default     = false
}

variable "auth_token" {
  description = "Redis AUTH token. Only applied when transit_encryption_enabled = true (ElastiCache constraint). Leave null when transit is off."
  type        = string
  default     = null
  sensitive   = true
}
