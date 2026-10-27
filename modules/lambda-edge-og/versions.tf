# Lambda@Edge must live in us-east-1; the caller passes providers = { aws = aws.us_east_1 }.
terraform {
  required_providers {
    aws     = { source = "hashicorp/aws" }
    archive = { source = "hashicorp/archive" }
  }
}
