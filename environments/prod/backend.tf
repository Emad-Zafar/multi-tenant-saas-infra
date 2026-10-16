# Terraform Remote Backend Configuration - Production
# Reuses the SAME state bucket and lock table as staging; isolation is by `key`.
# NOTE: backend blocks cannot use variables - every value here MUST be a literal.

terraform {
  backend "s3" {
    # S3 bucket for storing Terraform state (shared across environments)
    bucket = "saas-tf-state"

    # State file path within the bucket - UNIQUE per environment.
    # Staging uses "staging/terraform.tfstate"; prod is isolated under "prod/".
    key = "prod/terraform.tfstate"

    # AWS region for the S3 bucket and DynamoDB table
    region = "eu-north-1"

    # DynamoDB table for state locking (locks are per-key, so no collision with staging)
    dynamodb_table = "saas-tf-state-lock"

    # Enable encryption for state files
    encrypt = true

    # AWS profile to use for backend authentication
    profile = "terraform-ci"
  }
}
