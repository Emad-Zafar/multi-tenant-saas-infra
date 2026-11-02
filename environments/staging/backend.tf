# Terraform Remote Backend Configuration
# This file configures the S3 backend with DynamoDB state locking

terraform {
  backend "s3" {
    # S3 bucket for storing Terraform state
    bucket = "saas-tf-state"

    # State file path within the bucket
    key = "staging/terraform.tfstate"

    # AWS region for the S3 bucket and DynamoDB table
    # Note: If bucket exists in different region, update this value
    region = "eu-north-1"

    # DynamoDB table for state locking (prevents concurrent modifications)
    dynamodb_table = "saas-tf-state-lock"

    # Enable encryption for state files
    encrypt = true

    # AWS profile to use for backend authentication
    profile = "terraform-ci"
  }
}

