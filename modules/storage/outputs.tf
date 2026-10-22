# Storage module outputs

output "bucket_names" {
  description = "Map of logical key -> bucket name"
  value       = { for k, b in aws_s3_bucket.this : k => b.id }
}

output "bucket_arns" {
  description = "Map of logical key -> bucket ARN"
  value       = { for k, b in aws_s3_bucket.this : k => b.arn }
}

output "static_assets_bucket" {
  description = "Static assets bucket name (AWS_S3_STATIC_ASSETS_BUCKET)"
  value       = aws_s3_bucket.this["static_assets"].id
}

output "media_assets_bucket" {
  description = "Media assets bucket name (AWS_S3_INTERIM_MEDIA_BUCKET)"
  value       = aws_s3_bucket.this["media_assets"].id
}

output "knowledge_base_bucket" {
  description = "Knowledge base bucket name (AWS_S3_KNOWLEDGE_BASE_BUCKET)"
  value       = aws_s3_bucket.this["knowledge_base"].id
}
