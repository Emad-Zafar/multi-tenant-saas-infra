# Inputs for the monitoring module (CloudWatch alarms -> central alerts SNS topic).

variable "project" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "alarms_topic_arn" {
  description = "SNS topic ARN all alarms notify (ALARM + OK). Feeds email + Slack."
  type        = string
}

# --- Resource identifiers (CloudWatch dimensions) ---
variable "alb_arn_suffix" {
  description = "ALB ARN suffix (LoadBalancer dimension), e.g. app/name/hash."
  type        = string
}

variable "target_group_arn_suffix" {
  description = "Target group ARN suffix (TargetGroup dimension)."
  type        = string
}

variable "ecs_cluster_name" {
  description = "ECS cluster name."
  type        = string
}

variable "ecs_service_name" {
  description = "ECS API service name."
  type        = string
}

variable "rds_instance_id" {
  description = "RDS DBInstanceIdentifier."
  type        = string
}

variable "redis_node_id" {
  description = "ElastiCache CacheClusterId (node), e.g. <rg-id>-001."
  type        = string
}

variable "lambda_function_names" {
  description = "Lambda function names to alarm on Errors (map label -> function name)."
  type        = map(string)
  default     = {}
}

# --- Thresholds (sensible defaults; tune per real traffic) ---
variable "alb_5xx_threshold" {
  description = "ALB/target 5xx count over 5 min that trips a P1 alarm."
  type        = number
  default     = 50
}

variable "alb_4xx_threshold" {
  description = "ALB target 4xx count over 5 min (abuse/misuse surge). PLACEHOLDER - no traffic history; revisit after launch."
  type        = number
  default     = 100
}

variable "alb_request_count_threshold" {
  description = "ALB request count over 5 min, TOTAL across all users (not per-user). PLACEHOLDER - no traffic history; revisit after launch."
  type        = number
  default     = 5000
}

variable "alb_p95_latency_seconds" {
  description = "ALB target response time p95 (seconds). PLACEHOLDER - no traffic history; revisit after launch."
  type        = number
  default     = 2
}

variable "ecs_cpu_threshold" {
  description = "ECS service CPU utilization percent that trips."
  type        = number
  default     = 97
}

variable "ecs_memory_threshold" {
  description = "ECS service memory utilization percent that trips."
  type        = number
  default     = 97
}

variable "rds_free_storage_bytes" {
  description = "RDS free storage floor (bytes) below which a P1 alarm trips."
  type        = number
  default     = 5368709120 # 5 GiB
}

variable "rds_cpu_threshold" {
  description = "RDS CPU utilization percent that trips."
  type        = number
  default     = 95
}

variable "rds_connections_threshold" {
  description = "RDS open connections that trips (db.t4g.small max ~225; 200 leaves headroom)."
  type        = number
  default     = 200
}

variable "redis_cpu_threshold" {
  description = "Redis engine CPU utilization percent that trips."
  type        = number
  default     = 95
}

variable "redis_memory_threshold" {
  description = "Redis database memory usage percent that trips."
  type        = number
  default     = 95
}

variable "lambda_error_threshold" {
  description = "Lambda error count over 5 min that trips."
  type        = number
  default     = 5
}

variable "crash_loop_threshold" {
  description = "ECS task crashes (essential-container exits / failed starts) in 5 min that signal a crash loop."
  type        = number
  default     = 10
}

variable "period_seconds" {
  description = "Default evaluation period (seconds) for the alarms."
  type        = number
  default     = 300
}
