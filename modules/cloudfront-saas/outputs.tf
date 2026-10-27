# cloudfront-saas module outputs

output "frontend_bucket_name" {
  description = "S3 bucket for SPA build artifacts"
  value       = aws_s3_bucket.frontend.id
}

output "distribution_id" {
  description = "Multi-tenant CloudFront distribution ID"
  value       = aws_cloudfront_multitenant_distribution.this.id
}

output "connection_group_routing_endpoint" {
  description = "Connection group routing endpoint (CNAME target for tenant domains)"
  value       = aws_cloudfront_connection_group.this.routing_endpoint
}

output "test_tenant_domain" {
  description = "Domain of the test distribution tenant (null if not created)"
  value       = var.create_test_tenant ? var.test_tenant_domain : null
}

output "app_tenant_id" {
  description = "ID of the app distribution tenant (null if not created)"
  value       = try(aws_cloudfront_distribution_tenant.app[0].id, null)
}

output "app_tenant_arn" {
  description = "ARN of the app distribution tenant (null if not created)"
  value       = try(aws_cloudfront_distribution_tenant.app[0].arn, null)
}

output "app_tenant_routing_endpoint" {
  description = "Routing endpoint to CNAME app.example.com to when cutting DNS from Amplify (the connection group endpoint, shared by all tenants)"
  value       = var.create_app_tenant ? aws_cloudfront_connection_group.this.routing_endpoint : null
}
