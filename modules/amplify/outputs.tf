# Amplify module outputs

output "app_id" {
  description = "Amplify app ID"
  value       = aws_amplify_app.this.id
}

output "default_domain" {
  description = "Amplify app default domain (<app_id>.amplifyapp.com)"
  value       = aws_amplify_app.this.default_domain
}

output "branch_url" {
  description = "Default URL of the tracked branch"
  value       = "https://${aws_amplify_branch.this.branch_name}.${aws_amplify_app.this.default_domain}"
}

output "domain_association_arn" {
  description = "ARN of the custom domain association (null if not created)"
  value       = try(aws_amplify_domain_association.this[0].arn, null)
}

output "domain_certificate_verification_dns_record" {
  description = "DNS record for ACM cert verification (add to Route 53 if Amplify doesn't auto-create it)"
  value       = try(aws_amplify_domain_association.this[0].certificate_verification_dns_record, null)
}

output "custom_domain_dns_records" {
  description = "Per custom domain: the ACM cert-verification record + each sub_domain's routing record. Send these to the customer to add at their DNS provider."
  value = {
    for domain, assoc in aws_amplify_domain_association.custom : domain => {
      certificate_verification_dns_record = assoc.certificate_verification_dns_record
      sub_domains = [
        for s in assoc.sub_domain : {
          prefix     = s.prefix
          dns_record = s.dns_record
        }
      ]
    }
  }
}
