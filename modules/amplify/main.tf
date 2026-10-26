# SaaS web frontend on AWS Amplify Hosting.
# No custom domain and no /api proxy rewrite yet - those are later stages.

resource "aws_amplify_app" "this" {
  name         = var.app_name
  repository   = var.repository
  access_token = var.github_access_token

  build_spec            = var.build_spec
  environment_variables = var.environment_variables

  # Rule ORDER matters - Amplify evaluates top-down, first match wins.
  # 1) /api -> backend ALB (must come BEFORE the SPA catch-all).
  custom_rule {
    source = var.api_rewrite_source
    target = var.api_rewrite_target
    status = "200"
  }

  # 2) SPA 200-rewrite for React Router deep links (excludes static assets + /api).
  custom_rule {
    source = var.spa_rewrite_source
    target = "/index.html"
    status = "200"
  }

  tags = {
    Name        = var.app_name
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

resource "aws_amplify_branch" "this" {
  app_id            = aws_amplify_app.this.id
  branch_name       = var.branch_name
  enable_auto_build = var.enable_auto_build

  tags = {
    Name        = "${var.app_name}-${var.branch_name}"
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

# Custom domain. No certificate_settings block => Amplify-managed certificate,
# which covers app.example.com and the *.example.com wildcard.
resource "aws_amplify_domain_association" "this" {
  count                 = var.enable_custom_domain ? 1 : 0
  app_id                = aws_amplify_app.this.id
  domain_name           = var.domain_name
  wait_for_verification = var.domain_wait_for_verification

  dynamic "sub_domain" {
    for_each = var.domain_subdomain_prefixes
    content {
      branch_name = aws_amplify_branch.this.branch_name
      prefix      = sub_domain.value
    }
  }
}

# Per-tenant CUSTOM root domains (e.g. crm.acme.com) - one association each.
# Amplify-managed cert (no certificate_settings block).
resource "aws_amplify_domain_association" "custom" {
  for_each = var.custom_domains

  app_id                = aws_amplify_app.this.id
  domain_name           = each.key
  wait_for_verification = false

  sub_domain {
    branch_name = aws_amplify_branch.this.branch_name
    prefix      = each.value.prefix
  }
}
