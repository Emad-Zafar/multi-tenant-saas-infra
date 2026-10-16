# VPC endpoints for the prod VPC.
#
# - 5 INTERFACE endpoints (KMS, Secrets Manager, ECR api, ECR dkr, CloudWatch Logs)
#   placed in the private subnets, with private DNS enabled so the standard service
#   hostnames resolve to the endpoint ENIs.
# - 1 GATEWAY endpoint (S3) attached to the private route tables.
#
# Each endpoint is independently toggleable so it can be skipped if one already exists.

locals {
  # Logical name -> AWS service short suffix for the interface endpoints.
  interface_service_suffixes = {
    kms            = "kms"
    secretsmanager = "secretsmanager"
    ecr_api        = "ecr.api"
    ecr_dkr        = "ecr.dkr"
    logs           = "logs"
  }

  # Whether each interface endpoint is enabled.
  interface_enabled = {
    kms            = var.create_kms_endpoint
    secretsmanager = var.create_secretsmanager_endpoint
    ecr_api        = var.create_ecr_api_endpoint
    ecr_dkr        = var.create_ecr_dkr_endpoint
    logs           = var.create_logs_endpoint
  }

  # Filtered map of only the enabled interface endpoints (for for_each).
  enabled_interface_endpoints = {
    for name, suffix in local.interface_service_suffixes : name => suffix
    if local.interface_enabled[name]
  }

  any_interface_endpoint = length(local.enabled_interface_endpoints) > 0

  # Subnets for the interface endpoint ENIs: an explicit subset if given, else all.
  interface_subnet_ids = length(var.interface_endpoint_subnet_ids) > 0 ? var.interface_endpoint_subnet_ids : var.private_subnet_ids
}

# Security group for the interface endpoint ENIs - allow HTTPS from within the VPC.
resource "aws_security_group" "endpoints" {
  count       = local.any_interface_endpoint ? 1 : 0
  name        = "${var.project}-${var.environment}-vpce-sg"
  description = "Security group for interface VPC endpoints - HTTPS from within the VPC"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTPS from within the VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr_block]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project}-${var.environment}-vpce-sg"
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

# Interface endpoints
resource "aws_vpc_endpoint" "interface" {
  for_each = local.enabled_interface_endpoints

  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.${each.value}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = local.interface_subnet_ids
  security_group_ids  = [aws_security_group.endpoints[0].id]
  private_dns_enabled = true

  tags = {
    Name        = "${var.project}-${var.environment}-vpce-${each.key}-${var.aws_region}-01"
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

# S3 gateway endpoint
resource "aws_vpc_endpoint" "s3" {
  count = var.create_s3_gateway_endpoint ? 1 : 0

  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = var.private_route_table_ids

  tags = {
    Name        = "${var.project}-${var.environment}-vpce-s3-${var.aws_region}-01"
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}
