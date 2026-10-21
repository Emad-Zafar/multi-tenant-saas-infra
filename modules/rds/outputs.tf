# RDS module outputs

output "rds_instance_id" {
  description = "ID of the RDS instance"
  value       = aws_db_instance.this.id
}

output "rds_endpoint" {
  description = "RDS endpoint (host:port)"
  value       = aws_db_instance.this.endpoint
}

output "rds_address" {
  description = "RDS hostname"
  value       = aws_db_instance.this.address
}

output "rds_port" {
  description = "RDS port"
  value       = aws_db_instance.this.port
}

output "rds_database_name" {
  description = "Master/registry database name"
  value       = aws_db_instance.this.db_name
}

output "rds_master_username" {
  description = "Master username"
  value       = aws_db_instance.this.username
}

output "rds_master_user_secret_arn" {
  description = "ARN of the RDS-managed master user secret in Secrets Manager"
  value       = try(aws_db_instance.this.master_user_secret[0].secret_arn, null)
}
