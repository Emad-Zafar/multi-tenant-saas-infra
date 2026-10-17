# IAM Module Outputs

# EC2 Role Outputs
output "ec2_iam_role_id" {
  description = "ID of the EC2 IAM role"
  value       = aws_iam_role.saas_ec2_role.id
}

output "ec2_iam_role_arn" {
  description = "ARN of the EC2 IAM role"
  value       = aws_iam_role.saas_ec2_role.arn
}

output "ec2_iam_role_name" {
  description = "Name of the EC2 IAM role"
  value       = aws_iam_role.saas_ec2_role.name
}

output "ec2_instance_profile_id" {
  description = "ID of the EC2 instance profile"
  value       = aws_iam_instance_profile.saas_ec2_profile.id
}

output "ec2_instance_profile_arn" {
  description = "ARN of the EC2 instance profile"
  value       = aws_iam_instance_profile.saas_ec2_profile.arn
}

output "ec2_instance_profile_name" {
  description = "Name of the EC2 instance profile"
  value       = aws_iam_instance_profile.saas_ec2_profile.name
}

# Application User Outputs
output "app_user_id" {
  description = "ID of the application user"
  value       = aws_iam_user.saas_app_user.id
}

output "app_user_arn" {
  description = "ARN of the application user"
  value       = aws_iam_user.saas_app_user.arn
}

output "app_user_name" {
  description = "Name of the application user"
  value       = aws_iam_user.saas_app_user.name
}

output "app_user_access_key_id" {
  description = "Access key ID for application user (if created)"
  value       = var.create_app_user_access_key ? aws_iam_access_key.saas_app_user_key[0].id : null
  sensitive   = false
}

output "app_user_secret_access_key" {
  description = "Secret access key for application user (if created)"
  value       = var.create_app_user_access_key ? aws_iam_access_key.saas_app_user_key[0].secret : null
  sensitive   = true
}

# DevOps User Outputs
output "devops_user_id" {
  description = "ID of the DevOps user"
  value       = aws_iam_user.saas_devops_user.id
}

output "devops_user_arn" {
  description = "ARN of the DevOps user"
  value       = aws_iam_user.saas_devops_user.arn
}

output "devops_user_name" {
  description = "Name of the DevOps user"
  value       = aws_iam_user.saas_devops_user.name
}

output "devops_user_access_key_id" {
  description = "Access key ID for DevOps user (if created)"
  value       = var.create_devops_user_access_key ? aws_iam_access_key.saas_devops_user_key[0].id : null
  sensitive   = false
}

output "devops_user_secret_access_key" {
  description = "Secret access key for DevOps user (if created)"
  value       = var.create_devops_user_access_key ? aws_iam_access_key.saas_devops_user_key[0].secret : null
  sensitive   = true
}

