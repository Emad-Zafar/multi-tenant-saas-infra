# github-ci-user module outputs

output "user_name" {
  description = "IAM user name"
  value       = aws_iam_user.this.name
}

output "user_arn" {
  description = "IAM user ARN"
  value       = aws_iam_user.this.arn
}

output "access_key_id" {
  description = "Access key ID for the CI user"
  value       = aws_iam_access_key.this.id
}

output "secret_access_key" {
  description = "Secret access key for the CI user (sensitive)"
  value       = aws_iam_access_key.this.secret
  sensitive   = true
}
