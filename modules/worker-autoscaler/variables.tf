# Input variables for the worker-autoscaler module.

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

variable "subnet_ids" {
  description = "Subnets the Lambda runs in (AZ-a private subnet)"
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security group(s) for the Lambda ENIs (the dedicated autoscaler SG, created at the root)"
  type        = list(string)
}

variable "redis_host" {
  description = "Redis primary endpoint hostname (no auth)"
  type        = string
}

variable "cluster_name" {
  description = "ECS cluster name"
  type        = string
  default     = "saas-prod-cluster"
}

variable "service_name" {
  description = "ECS worker service name to scale"
  type        = string
  default     = "saas-prod-worker"
}

variable "schedule_expression" {
  description = "EventBridge Scheduler expression (1 minute; 90s is not expressible)"
  type        = string
  default     = "rate(1 minute)"
}

# --- Algorithm tunables (Lambda env) ---
variable "t_worker_per_min" {
  description = "Throughput per worker per minute"
  type        = number
  default     = 1500
}

variable "d_seconds" {
  description = "Target drain time (seconds) for the current backlog"
  type        = number
  default     = 180
}

variable "n_min" {
  description = "Minimum worker tasks"
  type        = number
  default     = 2
}

variable "n_max" {
  description = "Maximum worker tasks"
  type        = number
  default     = 6
}

variable "exclude_queues" {
  description = "Comma-separated queue names to exclude (e.g. the WhatsApp broadcast queue)"
  type        = string
  default     = ""
}

variable "lambda_timeout" {
  description = "Lambda timeout (seconds)"
  type        = number
  default     = 60
}

variable "lambda_memory" {
  description = "Lambda memory (MiB)"
  type        = number
  default     = 256
}

variable "log_retention_days" {
  description = "CloudWatch log retention for the Lambda (days)"
  type        = number
  default     = 90
}
