# Input variables for the Amplify module (SaaS web frontend).

variable "project" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "app_name" {
  description = "Amplify app name"
  type        = string
  default     = "saas-prod-web"
}

variable "repository" {
  description = "GitHub repository URL"
  type        = string
  default     = "https://github.com/your-org/saas-app"
}

variable "github_access_token" {
  description = "GitHub personal access token for Amplify to connect the repo (sensitive)"
  type        = string
  sensitive   = true
}

variable "branch_name" {
  description = "Git branch Amplify tracks"
  type        = string
  default     = "prod"
}

variable "enable_auto_build" {
  description = "Auto-build the branch on push"
  type        = bool
  default     = true
}

variable "environment_variables" {
  description = "App-level environment variables (VITE_API_URL intentionally omitted so it defaults to /api)"
  type        = map(string)
  default = {
    VITE_WHITELABELING_ENABLED = "true"
    VITE_WEBSOCKET_URL         = "wss://api.example.com"
  }
}

variable "enable_custom_domain" {
  description = "Create the aws_amplify_domain_association for the custom domain"
  type        = bool
  default     = false
}

variable "domain_name" {
  description = "Custom domain name to associate (Amplify provisions a managed cert covering the subdomains below)"
  type        = string
  default     = "example.com"
}

variable "domain_subdomain_prefixes" {
  description = "Subdomain prefixes to map to the branch. '*' is a wildcard for trial tenants."
  type        = list(string)
  default     = ["app", "*"]
}

variable "domain_wait_for_verification" {
  description = "Whether apply blocks until DNS verification completes"
  type        = bool
  default     = false
}

variable "custom_domains" {
  description = "Per-tenant custom root domains. Key = root domain (e.g. acme.com); value.prefix = subdomain (e.g. crm -> crm.acme.com). One Amplify-managed domain association each, mapped to the prod branch."
  type        = map(object({ prefix = string }))
  default     = {}
}

variable "api_rewrite_source" {
  description = "Source pattern for the /api proxy rewrite (must match before the SPA catch-all)"
  type        = string
  default     = "/api/<*>"
}

variable "api_rewrite_target" {
  description = "Target for the /api proxy rewrite (backend ALB via api.example.com, /api -> /api/v1)"
  type        = string
  default     = "https://api.example.com/api/v1/<*>"
}

variable "spa_rewrite_source" {
  description = "Source pattern for the SPA 200-rewrite. Default: AWS-recommended SPA regex that excludes static-asset extensions, with a negative lookahead excluding /api."
  type        = string
  default     = "</^(?!/api\\b)[^.]+$|\\.(?!(css|gif|ico|jpg|js|json|map|png|svg|ttf|txt|webp|woff|woff2)$)([^.]+$)/>"
}

variable "build_spec" {
  description = "Amplify build spec (monorepo, builds from repo root). Adjust the per-package build commands to match the repo's workspace setup."
  type        = string
  default     = <<-EOT
    version: 1
    frontend:
      phases:
        preBuild:
          commands:
            - npm ci
        build:
          commands:
            - npm run build --workspace packages/types
            - npm run build --workspace packages/shared
            - npm run build --workspace packages/ui
            - cd apps/web && NODE_OPTIONS=--max-old-space-size=3072 npm run build
      artifacts:
        baseDirectory: apps/web/dist
        files:
          - '**/*'
      cache:
        paths:
          - node_modules/**/*
  EOT
}
