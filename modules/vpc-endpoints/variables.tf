# Input variables for the VPC Endpoints module.
# Interface endpoints (KMS, Secrets Manager, ECR api/dkr, CloudWatch Logs) keep traffic
# from the private subnets on the AWS network instead of egressing via NAT. This is
# REQUIRED for the Phase-4 KMS key policy's aws:SourceVpce condition.

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
  description = "ID of the VPC the endpoints are created in"
  type        = string
}

variable "vpc_cidr_block" {
  description = "CIDR block of the VPC - used for the interface-endpoint security group ingress (HTTPS from inside the VPC)"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs the interface endpoint ENIs are placed in (default when interface_endpoint_subnet_ids is empty)"
  type        = list(string)
}

variable "interface_endpoint_subnet_ids" {
  description = "Subset of subnet IDs to place the interface endpoint ENIs in. Empty = use all private_subnet_ids. Set to a single subnet to run the endpoints in one AZ (cost)."
  type        = list(string)
  default     = []
}

variable "private_route_table_ids" {
  description = "Private route table IDs the S3 gateway endpoint attaches to"
  type        = list(string)
}

# --- Per-endpoint creation toggles (default true: create if missing) ---

variable "create_kms_endpoint" {
  description = "Create the KMS interface endpoint"
  type        = bool
  default     = true
}

variable "create_secretsmanager_endpoint" {
  description = "Create the Secrets Manager interface endpoint"
  type        = bool
  default     = true
}

variable "create_ecr_api_endpoint" {
  description = "Create the ECR API interface endpoint"
  type        = bool
  default     = true
}

variable "create_ecr_dkr_endpoint" {
  description = "Create the ECR Docker (dkr) interface endpoint"
  type        = bool
  default     = true
}

variable "create_logs_endpoint" {
  description = "Create the CloudWatch Logs interface endpoint"
  type        = bool
  default     = true
}

variable "create_s3_gateway_endpoint" {
  description = "Create the S3 gateway endpoint (attached to the private route tables)"
  type        = bool
  default     = true
}
