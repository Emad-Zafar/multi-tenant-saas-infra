# Input variables for the ECR module (API image repository).

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

variable "repository_name" {
  description = "ECR repository name for the API image"
  type        = string
  default     = "saas-prod-api"
}

variable "image_tag_mutability" {
  description = "Tag mutability (MUTABLE allows overwriting tags like :latest; IMMUTABLE forbids it)"
  type        = string
  default     = "MUTABLE"
}

variable "keep_last_images" {
  description = "Number of most recent tagged images to keep"
  type        = number
  default     = 10
}

variable "untagged_expire_days" {
  description = "Expire untagged images older than this many days"
  type        = number
  default     = 3
}
