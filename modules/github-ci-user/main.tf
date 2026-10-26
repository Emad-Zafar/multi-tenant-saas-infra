# Dedicated IAM user + access key for the prod GitHub Actions pipeline (no OIDC).

resource "aws_iam_user" "this" {
  name = var.user_name

  tags = {
    Name        = var.user_name
    Environment = var.environment
    Project     = var.project
    Purpose     = "GitHub Actions CI pipeline"
    ManagedBy   = "Terraform"
  }
}

resource "aws_iam_access_key" "this" {
  user = aws_iam_user.this.name
}

data "aws_iam_policy_document" "ci" {
  # ECR auth token is account-wide (cannot be resource-scoped).
  statement {
    sid       = "EcrAuth"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  # ECR push/pull scoped to the prod API repository.
  statement {
    sid = "EcrRepo"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
    ]
    resources = [var.ecr_repository_arn]
  }

  # ECS deploy scoped to the api + worker services.
  statement {
    sid       = "EcsDeploy"
    actions   = ["ecs:UpdateService", "ecs:DescribeServices"]
    resources = var.ecs_service_arns
  }

  # S3 sync to the frontend bucket.
  statement {
    sid       = "S3List"
    actions   = ["s3:ListBucket"]
    resources = [var.frontend_bucket_arn]
  }
  statement {
    sid       = "S3Objects"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${var.frontend_bucket_arn}/*"]
  }

  # CloudFront cache invalidation scoped to the distribution.
  statement {
    sid       = "CloudFrontInvalidate"
    actions   = ["cloudfront:CreateInvalidation"]
    resources = [var.cloudfront_distribution_arn]
  }

  # Per-tenant CloudFront invalidation (managed in code; previously added out-of-band).
  statement {
    sid       = "CloudFrontListTenants"
    actions   = ["cloudfront:ListDistributionTenants"]
    resources = ["*"]
  }
  statement {
    sid       = "CloudFrontInvalidateTenant"
    actions   = ["cloudfront:CreateInvalidationForDistributionTenant"]
    resources = [var.cloudfront_distribution_tenant_arn]
  }

  # ECS task-def registration for CI deploys (adopted from live; added out-of-band 2026-07-10).
  statement {
    sid       = "EcsTaskDefManage"
    effect    = "Allow"
    actions   = ["ecs:DescribeTaskDefinition", "ecs:RegisterTaskDefinition"]
    resources = ["*"]
  }

  # PassRole so CI can register task defs referencing the ECS task + execution roles.
  statement {
    sid     = "EcsPassRole"
    effect  = "Allow"
    actions = ["iam:PassRole"]
    resources = [
      "arn:aws:iam::111122223333:role/saas-prod-ecs-task-role-eu-north-1-01",
      "arn:aws:iam::111122223333:role/saas-prod-ecs-execution-role-eu-north-1-01",
    ]
  }
}

resource "aws_iam_user_policy" "ci" {
  name   = "${var.user_name}-policy"
  user   = aws_iam_user.this.name
  policy = data.aws_iam_policy_document.ci.json
}
