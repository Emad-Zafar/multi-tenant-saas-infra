# Declares the aws provider so callers can pass an aliased provider (e.g.
# aws.us_east_1) without a "reference to undefined provider" warning.
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}
