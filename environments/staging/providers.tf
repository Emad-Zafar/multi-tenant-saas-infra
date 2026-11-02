# Configure provider for Staging environment

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Backend configuration is in backend.tf
}

