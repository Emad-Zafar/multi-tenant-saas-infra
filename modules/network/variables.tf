# Input variables for Network module

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

variable "vpc_cidr_block" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "allowed_ssh_cidr_blocks" {
  description = "CIDR blocks allowed to SSH to EC2 instances. If empty, allows from anywhere (0.0.0.0/0). For production, restrict to specific IP ranges."
  type        = list(string)
  default     = ["0.0.0.0/0"] # Default allows from anywhere - should be restricted for production
}

variable "nat_per_az" {
  description = "If true, provision one NAT Gateway (and one private route table) per AZ for high availability. If false (default, the staging/dev behavior), a single shared NAT Gateway is created for cost savings."
  type        = bool
  default     = false
}

variable "create_default_security_groups" {
  description = "Whether to create the built-in EC2 and RDS security groups. Set to false for environments that define their own security groups (e.g. the prod ECS/ALB stack supplies its own via the security-groups module)."
  type        = bool
  default     = true
}

