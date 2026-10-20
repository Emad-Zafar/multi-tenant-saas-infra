# Input variables for the ACM module (one DNS-validated certificate).
# The caller selects the region by passing a provider (default or aws.us_east_1).

variable "project" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "domain_name" {
  description = "Fully-qualified domain name for the certificate (e.g. api.example.com)"
  type        = string
}

variable "route53_zone_id" {
  description = "Route 53 hosted zone ID where DNS validation records are created"
  type        = string
}

variable "validation_record_ttl" {
  description = "TTL (seconds) for the DNS validation records"
  type        = number
  default     = 60
}
