# Input variables for the ECS + ALB module (prod API, Fargate).

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

# --- Networking ---
variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for the internet-facing ALB"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for the Fargate tasks (default placement)"
  type        = list(string)
}

variable "service_subnet_ids" {
  description = "Subnets the ECS service places tasks in. Empty = all private_subnet_ids. Set to a single subnet to pin the service to one AZ. Does NOT affect the ALB."
  type        = list(string)
  default     = []
}

variable "alb_security_group_id" {
  description = "ALB security group ID"
  type        = string
}

variable "ecs_security_group_id" {
  description = "ECS task security group ID"
  type        = string
}

variable "certificate_arn" {
  description = "Regional ACM certificate ARN for the HTTPS listener (api.example.com)"
  type        = string
}

# --- Container ---
variable "container_image" {
  description = "Full image reference for the API (ECR URL + tag)"
  type        = string
}

variable "container_port" {
  description = "Port the API listens on"
  type        = number
  default     = 3000
}

variable "task_cpu" {
  description = "Fargate task CPU units"
  type        = number
  default     = 512
}

variable "task_memory" {
  description = "Fargate task memory (MiB)"
  type        = number
  default     = 1024
}

variable "execution_role_arn" {
  description = "ECS task execution role ARN"
  type        = string
}

variable "task_role_arn" {
  description = "ECS task (runtime app identity) role ARN"
  type        = string
}

variable "log_retention_days" {
  description = "CloudWatch log group retention (days)"
  type        = number
  default     = 30
}

variable "container_insights" {
  description = "ECS cluster Container Insights setting (enabled/disabled)"
  type        = string
  default     = "disabled"
}

# --- Env + secrets ---
variable "plain_environment" {
  description = "Plain (non-sensitive) environment variables for the container. SKIP_MIGRATIONS is stripped for the migration task def."
  type        = map(string)
}

variable "db_host" {
  description = "Overrides DB_HOST for the MAIN (API) task only (e.g. the RDS Proxy endpoint). The migration task keeps the DB_HOST from plain_environment (direct RDS). Empty = no override."
  type        = string
  default     = ""
}

variable "container_secrets" {
  description = "Map of ENV_VAR_NAME -> top-level JSON key within the bundled app secret. Injected via the task-def secrets block."
  type        = map(string)
}

variable "app_secret_arn" {
  description = "ARN of the bundled app secret (saas/prod/app)"
  type        = string
}

# --- Service / scaling ---
variable "desired_count" {
  description = "Initial desired task count (0 = deploy nothing until migrations run, then scale up)"
  type        = number
  default     = 0
}

variable "min_capacity" {
  description = "Autoscaling minimum task count"
  type        = number
  default     = 0
}

variable "max_capacity" {
  description = "Autoscaling maximum task count"
  type        = number
  default     = 4
}

variable "cpu_target_value" {
  description = "Target average CPU utilization (%) for autoscaling"
  type        = number
  default     = 60
}

variable "health_check_path" {
  description = "ALB target group health check path"
  type        = string
  default     = "/health"
}

variable "ssl_policy" {
  description = "ALB HTTPS listener SSL policy"
  type        = string
  default     = "ELBSecurityPolicy-TLS13-1-2-2021-06"
}

# --- Worker tier ---
variable "enable_worker" {
  description = "Create the worker task definition + service"
  type        = bool
  default     = false
}

variable "worker_security_group_id" {
  description = "Security group ID for the worker service tasks"
  type        = string
  default     = ""
}

variable "worker_subnet_ids" {
  description = "Subnets for the worker tasks (e.g. AZ-a only). Empty = fall back to the service/private subnets."
  type        = list(string)
  default     = []
}

variable "worker_cpu" {
  description = "Worker Fargate task CPU units"
  type        = number
  default     = 512
}

variable "worker_memory" {
  description = "Worker Fargate task memory (MiB)"
  type        = number
  default     = 1024
}

variable "worker_desired_count" {
  description = "Initial worker task count (autoscaler manages it later)"
  type        = number
  default     = 1
}

variable "worker_stop_timeout" {
  description = "Worker container stopTimeout (seconds) for graceful shutdown"
  type        = number
  default     = 120
}

variable "worker_log_retention_days" {
  description = "Retention (days) for the worker log group"
  type        = number
  default     = 90
}
