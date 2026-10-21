# Prod ElastiCache Redis - single node, cluster mode disabled (required for BullMQ),
# at-rest encryption with the CMK. In-transit encryption is optional (off by default);
# auth_token is only valid when in-transit encryption is enabled.

# Custom parameter group to control the eviction policy.
resource "aws_elasticache_parameter_group" "this" {
  count       = var.create_parameter_group ? 1 : 0
  name        = "${var.project}-${var.environment}-redis-params"
  family      = var.parameter_group_family
  description = "${var.project}-${var.environment} Redis parameters (maxmemory-policy=${var.maxmemory_policy})"

  parameter {
    name  = "maxmemory-policy"
    value = var.maxmemory_policy
  }

  tags = {
    Name        = "${var.project}-${var.environment}-redis-params"
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

resource "aws_elasticache_subnet_group" "this" {
  name       = "${var.project}-${var.environment}-redis-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name        = "${var.project}-${var.environment}-redis-subnet-group"
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

resource "aws_elasticache_replication_group" "this" {
  replication_group_id = "${var.project}-${var.environment}-redis"
  description          = "${var.project}-${var.environment} Redis (single node, non-cluster)"

  engine         = "redis"
  engine_version = var.engine_version
  node_type      = var.node_type
  port           = 6379

  # Single node, cluster mode disabled, no failover (cost).
  num_cache_clusters         = 1
  automatic_failover_enabled = false
  multi_az_enabled           = false

  subnet_group_name    = aws_elasticache_subnet_group.this.name
  security_group_ids   = [var.redis_security_group_id]
  parameter_group_name = var.create_parameter_group ? aws_elasticache_parameter_group.this[0].name : var.parameter_group_name

  # At-rest encryption with the customer-managed key.
  at_rest_encryption_enabled = true
  kms_key_id                 = var.kms_key_arn

  # In-transit encryption (off by default). auth_token only valid when this is true.
  transit_encryption_enabled = var.transit_encryption_enabled
  auth_token                 = var.transit_encryption_enabled ? var.auth_token : null

  tags = {
    Name        = "${var.project}-${var.environment}-redis"
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}
