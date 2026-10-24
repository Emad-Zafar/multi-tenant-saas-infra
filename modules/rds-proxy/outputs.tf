# rds-proxy module outputs

output "proxy_endpoint" {
  description = "RDS Proxy endpoint hostname (use as DB_HOST instead of the RDS instance)"
  value       = aws_db_proxy.this.endpoint
}

output "proxy_arn" {
  description = "RDS Proxy ARN"
  value       = aws_db_proxy.this.arn
}

output "proxy_security_group_id" {
  description = "Security group ID of the RDS Proxy (allow this on the RDS SG)"
  value       = aws_security_group.proxy.id
}

output "proxy_secret_arn" {
  description = "ARN of the dedicated proxy credentials secret"
  value       = aws_secretsmanager_secret.proxy.arn
}
