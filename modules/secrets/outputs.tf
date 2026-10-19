# Secrets module outputs

output "kms_key_arn" {
  description = "ARN of the customer-managed KMS key"
  value       = aws_kms_key.this.arn
}

output "kms_key_id" {
  description = "ID of the customer-managed KMS key"
  value       = aws_kms_key.this.key_id
}

output "kms_alias_name" {
  description = "Alias of the customer-managed KMS key"
  value       = aws_kms_alias.this.name
}

output "tenant_kms_key_arn" {
  description = "ARN of the dedicated tenant-secrets KMS key"
  value       = aws_kms_key.tenant.arn
}

output "tenant_kms_alias_name" {
  description = "Alias of the tenant-secrets KMS key"
  value       = aws_kms_alias.tenant.name
}

output "execution_role_arn" {
  description = "ARN of the ECS task execution role"
  value       = aws_iam_role.execution.arn
}

output "execution_role_name" {
  description = "Name of the ECS task execution role"
  value       = aws_iam_role.execution.name
}

output "task_role_arn" {
  description = "ARN of the ECS task (runtime app identity) role"
  value       = aws_iam_role.task.arn
}

output "task_role_name" {
  description = "Name of the ECS task role"
  value       = aws_iam_role.task.name
}

output "app_secret_arn" {
  description = "ARN of the bundled application secret"
  value       = aws_secretsmanager_secret.app.arn
}

output "tenant_secret_prefix" {
  description = "Secrets Manager name prefix for per-tenant secrets"
  value       = var.tenant_secret_prefix
}
