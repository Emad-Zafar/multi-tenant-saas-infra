# One DNS-validated ACM certificate.
# Region is chosen by the provider the caller passes in:
#   - default provider  -> regional cert (eu-north-1, for the ALB)
#   - aws.us_east_1      -> us-east-1 cert (for Amplify / CloudFront)
# Route 53 is global, so the validation records live in the same example.com zone
# regardless of the certificate's region.

resource "aws_acm_certificate" "this" {
  domain_name       = var.domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    # AWS rejects "*" in tag values, so wildcard domains become "wildcard.<rest>".
    Name        = replace(var.domain_name, "*", "wildcard")
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

# DNS validation record(s) in Route 53.
resource "aws_route53_record" "validation" {
  for_each = {
    for dvo in aws_acm_certificate.this.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  zone_id         = var.route53_zone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.record]
  ttl             = var.validation_record_ttl
  allow_overwrite = true
}

# Waits until the certificate is issued (DNS validation complete).
resource "aws_acm_certificate_validation" "this" {
  certificate_arn         = aws_acm_certificate.this.arn
  validation_record_fqdns = [for r in aws_route53_record.validation : r.fqdn]
}
