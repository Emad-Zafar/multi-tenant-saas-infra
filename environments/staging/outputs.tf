# Staging Environment Outputs

# Network Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.network.vpc_id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = module.network.vpc_cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.network.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = module.network.private_subnet_ids
}

# Compute Outputs
output "ec2_instance_id" {
  description = "ID of the EC2 instance"
  value       = module.compute.ec2_instance_id
}

output "ec2_instance_public_ip" {
  description = "Public IP (Elastic IP) of the EC2 instance"
  value       = module.compute.ec2_instance_public_ip
}

output "ec2_instance_private_ip" {
  description = "Private IP of the EC2 instance"
  value       = module.compute.ec2_instance_private_ip
}

output "ssh_command" {
  description = "SSH command to connect to the EC2 instance"
  value       = module.compute.ssh_command
}

# Data Outputs
output "rds_endpoint" {
  description = "RDS PostgreSQL endpoint"
  value       = module.data.rds_endpoint
}

output "rds_address" {
  description = "RDS PostgreSQL address"
  value       = module.data.rds_address
}

output "rds_port" {
  description = "RDS PostgreSQL port"
  value       = module.data.rds_port
}

output "rds_connection_string" {
  description = "PostgreSQL connection string (without password - password is in Secrets Manager)"
  value       = module.data.rds_connection_string
  sensitive   = false
}

output "rds_master_user_secret_arn" {
  description = "ARN of the master user secret in AWS Secrets Manager (contains the database password)"
  value       = module.data.rds_master_user_secret_arn
  sensitive   = false
}

output "rds_master_username" {
  description = "Master username for the database"
  value       = module.data.rds_master_username
  sensitive   = false
}

output "s3_bucket_id" {
  description = "ID of the S3 bucket"
  value       = module.data.s3_bucket_id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = module.data.s3_bucket_arn
}

# IAM Outputs
output "ec2_iam_role_arn" {
  description = "ARN of the EC2 IAM role"
  value       = module.iam.ec2_iam_role_arn
}

output "app_user_name" {
  description = "Name of the application IAM user"
  value       = module.iam.app_user_name
}

output "devops_user_name" {
  description = "Name of the DevOps IAM user"
  value       = module.iam.devops_user_name
}

