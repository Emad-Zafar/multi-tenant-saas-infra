# Input variables for the lambda-edge-og module.

variable "project" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "function_name" {
  description = "Lambda@Edge function name"
  type        = string
  default     = "saas-prod-edge-og"
}

variable "timeout" {
  description = "Function timeout in seconds (viewer-request max is 5)"
  type        = number
  default     = 5
}

variable "memory" {
  description = "Function memory (MiB)"
  type        = number
  default     = 128
}
