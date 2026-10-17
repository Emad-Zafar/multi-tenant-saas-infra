# Input variables for the Security Groups module (prod ECS/ALB stack).

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

variable "vpc_id" {
  description = "ID of the VPC the security groups belong to"
  type        = string
}

variable "container_port" {
  description = "Port the NestJS API container listens on (the ALB forwards to this port on the ECS tasks)"
  type        = number
  default     = 3000
}

variable "alb_ingress_cidr_blocks" {
  description = "CIDR blocks allowed to reach the ALB on 443. Public-facing by default."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "rds_proxy_security_group_id" {
  description = "If set, add an inline ingress on the RDS SG allowing 5432 from the RDS Proxy SG. Kept inline here (not a standalone rule) to avoid inline/standalone rule conflicts."
  type        = string
  default     = null
}

variable "rds_cloudshell_ingress_security_group_id" {
  description = "If set, add an inline ingress on the RDS SG allowing 5432 from this SG (e.g. the CloudShell/admin DB-access SG). Managed in code so it isn't wiped as drift."
  type        = string
  default     = null
}

variable "worker_security_group_id" {
  description = "If set, add an inline ingress on the Redis SG allowing 6379 from the worker SG."
  type        = string
  default     = null
}

variable "autoscaler_security_group_id" {
  description = "If set, add an inline ingress on the Redis SG allowing 6379 from the worker-autoscaler Lambda SG."
  type        = string
  default     = null
}
