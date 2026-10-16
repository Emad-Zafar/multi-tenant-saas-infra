# Configure providers for the Production environment

# Default provider - eu-north-1 (all primary resources live here)
provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

# Aliased provider - us-east-1.
# Required because ACM certificates consumed by Amplify (and CloudFront) MUST be
# created in us-east-1, regardless of where the rest of the stack lives.
provider "aws" {
  alias   = "us_east_1"
  region  = "us-east-1"
  profile = var.aws_profile
}

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.28"
    }
  }

  # Backend configuration is in backend.tf
}
