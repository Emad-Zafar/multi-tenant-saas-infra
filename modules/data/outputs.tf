# Data Module Outputs

# RDS Outputs
output "rds_instance_id" {
  description = "ID of the RDS instance"
  value       = aws_db_instance.saas_postgres.id
}

output "rds_instance_arn" {
  description = "ARN of the RDS instance"
  value       = aws_db_instance.saas_postgres.arn
}

output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.saas_postgres.endpoint
}

output "rds_address" {
  description = "RDS instance address"
  value       = aws_db_instance.saas_postgres.address
}

output "rds_port" {
  description = "RDS instance port"
  value       = aws_db_instance.saas_postgres.port
}

output "rds_database_name" {
  description = "Name of the database"
  value       = aws_db_instance.saas_postgres.db_name
}

output "rds_master_username" {
  description = "Master username for the database"
  value       = aws_db_instance.saas_postgres.username
}

output "rds_master_user_secret_arn" {
  description = "ARN of the master user secret in AWS Secrets Manager containing the database password"
  value       = try(aws_db_instance.saas_postgres.master_user_secret[0].secret_arn, null)
  sensitive   = false
}

output "rds_connection_string" {
  description = "PostgreSQL connection string (without password - password is in Secrets Manager)"
  value       = "postgresql://${aws_db_instance.saas_postgres.username}@${aws_db_instance.saas_postgres.endpoint}/${aws_db_instance.saas_postgres.db_name}"
}

# S3 Outputs
output "s3_bucket_id" {
  description = "ID of the S3 bucket"
  value       = aws_s3_bucket.saas_storage.id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.saas_storage.arn
}

output "s3_bucket_domain_name" {
  description = "Domain name of the S3 bucket"
  value       = aws_s3_bucket.saas_storage.bucket_domain_name
}

output "s3_bucket_regional_domain_name" {
  description = "Regional domain name of the S3 bucket"
  value       = aws_s3_bucket.saas_storage.bucket_regional_domain_name
}

