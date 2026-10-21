# Cache (Redis) module outputs

output "redis_primary_endpoint" {
  description = "Primary endpoint address of the Redis replication group"
  value       = aws_elasticache_replication_group.this.primary_endpoint_address
}

output "redis_port" {
  description = "Redis port"
  value       = aws_elasticache_replication_group.this.port
}

output "redis_replication_group_id" {
  description = "Redis replication group ID"
  value       = aws_elasticache_replication_group.this.replication_group_id
}

output "transit_encryption_enabled" {
  description = "Whether in-transit encryption (and therefore AUTH) is enabled"
  value       = aws_elasticache_replication_group.this.transit_encryption_enabled
}
