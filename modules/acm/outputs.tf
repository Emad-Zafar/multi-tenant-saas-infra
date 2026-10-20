# ACM module outputs

output "certificate_arn" {
  description = "ARN of the validated ACM certificate"
  value       = aws_acm_certificate_validation.this.certificate_arn
}

output "domain_name" {
  description = "Certificate domain name"
  value       = aws_acm_certificate.this.domain_name
}
