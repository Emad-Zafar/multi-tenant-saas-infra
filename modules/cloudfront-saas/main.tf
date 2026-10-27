# CloudFront SaaS Manager foundation (multi-tenant distribution) ALONGSIDE Amplify.
# No DNS, Amplify, or ALB changes. No distribution tenants created here.

# ---------------------------------------------------------------------------
# S3 bucket for SPA build artifacts (private, versioned, SSE; OAC read only)
# ---------------------------------------------------------------------------
resource "aws_s3_bucket" "frontend" {
  bucket = var.bucket_name

  tags = {
    Name        = var.bucket_name
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket                  = aws_s3_bucket.frontend.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# ---------------------------------------------------------------------------
# Origin Access Control (sigv4 / s3 / always)
# ---------------------------------------------------------------------------
resource "aws_cloudfront_origin_access_control" "frontend" {
  name                              = "${var.project}-${var.environment}-frontend-oac"
  description                       = "OAC for the ${var.project}-${var.environment} frontend bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# ---------------------------------------------------------------------------
# Connection group (routing endpoint tenants CNAME to)
# ---------------------------------------------------------------------------
resource "aws_cloudfront_connection_group" "this" {
  name         = var.connection_group_name
  enabled      = true
  ipv6_enabled = true

  tags = {
    Name        = var.connection_group_name
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

# ---------------------------------------------------------------------------
# AWS managed cache / origin-request policies
# ---------------------------------------------------------------------------
data "aws_cloudfront_cache_policy" "optimized" {
  name = "Managed-CachingOptimized"
}

data "aws_cloudfront_cache_policy" "disabled" {
  name = "Managed-CachingDisabled"
}

# Origin request policy for the API (custom ALB) origin: AWS-managed
# "AllViewerExceptHostHeader". Forwards ALL viewer headers, cookies, and query strings to
# the origin EXCEPT the Host header.
#
# Why not forward Host: this is a custom origin (the ALB). Forwarding the viewer Host (the
# tenant domain, e.g. app.example.com) would make CloudFront send that as the origin Host,
# breaking the ALB's TLS/SNI + host-based routing - the origin must receive its own hostname
# (api.example.com). The backend resolves the tenant from the forwarded Origin header, not Host.
#
# Why not a whitelist: the previous custom policy whitelisted a fixed set of headers and
# silently dropped anything not listed (it already needed an out-of-band patch to add
# x-tenant-domain). "AllViewerExceptHostHeader" forwards every current and future app header
# automatically while preserving the one intentional exclusion (Host).
data "aws_cloudfront_origin_request_policy" "all_viewer_except_host" {
  name = "Managed-AllViewerExceptHostHeader"
}

# ---------------------------------------------------------------------------
# Multi-tenant distribution
# ---------------------------------------------------------------------------
resource "aws_cloudfront_multitenant_distribution" "this" {
  comment             = "${var.project}-${var.environment} multi-tenant SaaS distribution"
  enabled             = true
  default_root_object = "index.html"
  # connection_mode is read-only here - the multitenant resource is implicitly tenant-only.

  # (a) S3 frontend via OAC - default origin.
  origin {
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    id                       = "s3-frontend"
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend.id
  }

  # (b) ALB (api.example.com) as a custom HTTPS origin for API traffic.
  origin {
    domain_name = var.alb_domain_name
    id          = "alb-api"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # Default behavior -> S3 (SPA), HTTPS redirect, GET/HEAD.
  default_cache_behavior {
    target_origin_id       = "s3-frontend"
    viewer_protocol_policy = "redirect-to-https"
    cache_policy_id        = data.aws_cloudfront_cache_policy.optimized.id

    allowed_methods {
      items          = ["GET", "HEAD"]
      cached_methods = ["GET", "HEAD"]
    }

    # OG link-preview Lambda@Edge on viewer-request (only when an ARN is supplied).
    # Note: this resource uses `lambda_function_arn` (not `lambda_arn`).
    dynamic "lambda_function_association" {
      for_each = var.og_lambda_qualified_arn != "" ? [1] : []
      content {
        event_type          = "viewer-request"
        lambda_function_arn = var.og_lambda_qualified_arn
        include_body        = false
      }
    }
  }

  # /api/* -> ALB, no caching, forward everything, all methods.
  cache_behavior {
    path_pattern             = "/api/*"
    target_origin_id         = "alb-api"
    viewer_protocol_policy   = "redirect-to-https"
    cache_policy_id          = data.aws_cloudfront_cache_policy.disabled.id
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.all_viewer_except_host.id

    allowed_methods {
      items          = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
      cached_methods = ["GET", "HEAD"]
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # Base distribution uses the default CloudFront cert; per-tenant certs are attached
  # to distribution tenants later.
  viewer_certificate {
    cloudfront_default_certificate = true
  }

  # Parameter definitions for the multi-tenant config.
  tenant_config {
    parameter_definition {
      name = "tenantDomain"
      definition {
        string_schema {
          required = false
          comment  = "Per-tenant custom domain"
          # AWS requires an optional parameter to carry a default_value. Placeholder
          # only - this parameter isn't referenced by any origin.
          default_value = "root"
        }
      }
    }
  }

  tags = {
    Name        = "${var.project}-${var.environment}-saas-distribution"
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

# ---------------------------------------------------------------------------
# Bucket policy: read ONLY to the distribution via OAC
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "frontend" {
  statement {
    sid     = "AllowCloudFrontOACRead"
    effect  = "Allow"
    actions = ["s3:GetObject"]
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    resources = ["${aws_s3_bucket.frontend.arn}/*"]
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_multitenant_distribution.this.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  policy = data.aws_iam_policy_document.frontend.json

  depends_on = [aws_s3_bucket_public_access_block.frontend]
}

# ---------------------------------------------------------------------------
# Test distribution tenant (gated; easy to remove via create_test_tenant=false)
# ---------------------------------------------------------------------------
resource "aws_cloudfront_distribution_tenant" "test" {
  count               = var.create_test_tenant ? 1 : 0
  name                = "${var.project}-${var.environment}-cf-test"
  distribution_id     = aws_cloudfront_multitenant_distribution.this.id
  connection_group_id = aws_cloudfront_connection_group.this.id
  enabled             = true

  domain {
    domain = var.test_tenant_domain
  }

  # CloudFront-managed certificate (auto-issue + auto-validate via the routing endpoint).
  managed_certificate_request {
    primary_domain_name                         = var.test_tenant_domain
    certificate_transparency_logging_preference = "enabled"
    validation_token_host                       = "cloudfront"
  }

  parameter {
    name  = "tenantDomain"
    value = var.test_tenant_domain
  }

  tags = {
    Name        = "${var.project}-${var.environment}-cf-test"
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }

  # CloudFront auto-populates a customizations block the provider doesn't plan for,
  # causing "inconsistent result after apply". Ignore it.
  lifecycle {
    ignore_changes = [customizations]
  }
}

# Route53 CNAME: cf-test.example.com -> connection group routing endpoint.
resource "aws_route53_record" "test_tenant" {
  count   = var.create_test_tenant ? 1 : 0
  zone_id = var.route53_zone_id
  name    = var.test_tenant_domain
  type    = "CNAME"
  ttl     = 300
  records = [aws_cloudfront_connection_group.this.routing_endpoint]
}

# ---------------------------------------------------------------------------
# App distribution tenant (app.example.com). NO Route53 change - DNS stays on Amplify.
# ---------------------------------------------------------------------------
resource "aws_cloudfront_distribution_tenant" "app" {
  count               = var.create_app_tenant ? 1 : 0
  name                = "${var.project}-${var.environment}-app"
  distribution_id     = aws_cloudfront_multitenant_distribution.this.id
  connection_group_id = aws_cloudfront_connection_group.this.id
  enabled             = true

  domain {
    domain = var.app_tenant_domain
  }

  managed_certificate_request {
    primary_domain_name                         = var.app_tenant_domain
    certificate_transparency_logging_preference = "enabled"
    validation_token_host                       = "cloudfront"
  }

  parameter {
    name  = "tenantDomain"
    value = var.app_tenant_domain
  }

  # DNS for app.example.com cuts over to CloudFront in the same apply; don't block the
  # apply waiting on cert validation/deployment.
  wait_for_deployment = false

  tags = {
    Name        = "${var.project}-${var.environment}-app"
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }

  lifecycle {
    ignore_changes = [customizations]
  }
}

# app.example.com -> multitenant connection group routing endpoint (CNAME).
# allow_overwrite takes the record over from the Amplify-managed one.
resource "aws_route53_record" "app_tenant" {
  count           = var.create_app_tenant ? 1 : 0
  zone_id         = var.route53_zone_id
  name            = var.app_tenant_domain
  type            = "CNAME"
  ttl             = 300
  records         = [aws_cloudfront_connection_group.this.routing_endpoint]
  allow_overwrite = true
}
