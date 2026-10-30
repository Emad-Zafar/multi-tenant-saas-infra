# Secret-access audit pipeline.
#
# In a "zero-issue" environment humans only create/delete secrets; only machines
# (the ECS task role, an AssumedRole) read them. This module notifies when a HUMAN
# reads a secret, via:
#   CloudTrail -> CloudWatch Logs -> subscription filter -> notifier Lambda -> SNS.
#
# The subscription filter matches GetSecretValue by an IAM *user* while EXCLUDING SDK/CLI
# user-agents (automation authenticating with a personal access key looks like an IAMUser
# too - that was flooding the old alarm). What survives the filter is genuine human/console
# access, and the Lambda publishes an SNS message naming who read which secret.

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition

  trail_name     = "${var.project}-${var.environment}-trail"
  trail_arn      = "arn:${local.partition}:cloudtrail:${var.aws_region}:${local.account_id}:trail/${local.trail_name}"
  trail_bucket   = "${var.project}-${var.environment}-cloudtrail-${local.account_id}"
  log_group_name = var.create_cloudtrail ? aws_cloudwatch_log_group.trail[0].name : var.existing_cloudtrail_log_group_name
  log_group_arn  = var.create_cloudtrail ? aws_cloudwatch_log_group.trail[0].arn : "arn:${local.partition}:logs:${var.aws_region}:${local.account_id}:log-group:${var.existing_cloudtrail_log_group_name}"

  notifier_name = "${var.project}-${var.environment}-secret-access-notifier"

  # CloudTrail JSON pattern: GetSecretValue by an IAM user, EXCLUDING SDK/CLI callers.
  # AssumedRole (the ECS task) is excluded by userIdentity.type; scripts using a personal
  # access key are excluded by user-agent so only human/console reads notify.
  human_get_secret_pattern = "{ ($.eventSource = \"secretsmanager.amazonaws.com\") && ($.eventName = \"GetSecretValue\") && ($.userIdentity.type = \"IAMUser\") && ($.userAgent != \"aws-sdk*\") && ($.userAgent != \"Boto3*\") && ($.userAgent != \"aws-cli*\") && ($.userAgent != \"*botocore*\") }"
}

# --- SNS topic for the alarm ---
resource "aws_sns_topic" "secret_access" {
  name = "${var.project}-${var.environment}-secret-access-alarm"

  tags = {
    Name        = "${var.project}-${var.environment}-secret-access-alarm"
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

# ---------------------------------------------------------------------------
# CloudTrail pipeline (created only when create_cloudtrail = true)
# ---------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "trail" {
  count             = var.create_cloudtrail ? 1 : 0
  name              = "/aws/cloudtrail/${local.trail_name}"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "/aws/cloudtrail/${local.trail_name}"
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

# IAM role allowing CloudTrail to write to the log group.
data "aws_iam_policy_document" "trail_assume" {
  count = var.create_cloudtrail ? 1 : 0
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "trail_to_logs" {
  count              = var.create_cloudtrail ? 1 : 0
  name               = "${var.project}-${var.environment}-cloudtrail-logs-role-${var.aws_region}-01"
  assume_role_policy = data.aws_iam_policy_document.trail_assume[0].json

  tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

data "aws_iam_policy_document" "trail_to_logs" {
  count = var.create_cloudtrail ? 1 : 0
  statement {
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.trail[0].arn}:*"]
  }
}

resource "aws_iam_role_policy" "trail_to_logs" {
  count  = var.create_cloudtrail ? 1 : 0
  name   = "${var.project}-${var.environment}-cloudtrail-logs-policy"
  role   = aws_iam_role.trail_to_logs[0].id
  policy = data.aws_iam_policy_document.trail_to_logs[0].json
}

# S3 bucket for the trail (CloudTrail's primary, durable destination).
resource "aws_s3_bucket" "trail" {
  count         = var.create_cloudtrail ? 1 : 0
  bucket        = local.trail_bucket
  force_destroy = false

  tags = {
    Name        = local.trail_bucket
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

resource "aws_s3_bucket_public_access_block" "trail" {
  count                   = var.create_cloudtrail ? 1 : 0
  bucket                  = aws_s3_bucket.trail[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "trail" {
  count  = var.create_cloudtrail ? 1 : 0
  bucket = aws_s3_bucket.trail[0].id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

data "aws_iam_policy_document" "trail_bucket" {
  count = var.create_cloudtrail ? 1 : 0

  statement {
    sid     = "AWSCloudTrailAclCheck"
    effect  = "Allow"
    actions = ["s3:GetBucketAcl"]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    resources = [aws_s3_bucket.trail[0].arn]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [local.trail_arn]
    }
  }

  statement {
    sid     = "AWSCloudTrailWrite"
    effect  = "Allow"
    actions = ["s3:PutObject"]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    resources = ["${aws_s3_bucket.trail[0].arn}/AWSLogs/${local.account_id}/*"]
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [local.trail_arn]
    }
  }
}

resource "aws_s3_bucket_policy" "trail" {
  count  = var.create_cloudtrail ? 1 : 0
  bucket = aws_s3_bucket.trail[0].id
  policy = data.aws_iam_policy_document.trail_bucket[0].json
}

resource "aws_cloudtrail" "this" {
  count                         = var.create_cloudtrail ? 1 : 0
  name                          = local.trail_name
  s3_bucket_name                = aws_s3_bucket.trail[0].id
  is_multi_region_trail         = true
  include_global_service_events = true
  enable_log_file_validation    = true
  cloud_watch_logs_group_arn    = "${aws_cloudwatch_log_group.trail[0].arn}:*"
  cloud_watch_logs_role_arn     = aws_iam_role.trail_to_logs[0].arn

  tags = {
    Name        = local.trail_name
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }

  depends_on = [aws_s3_bucket_policy.trail]
}

# ---------------------------------------------------------------------------
# Notifier Lambda + subscription filter (created when a log group is available)
# ---------------------------------------------------------------------------

data "archive_file" "notifier" {
  count       = local.log_group_name != "" ? 1 : 0
  type        = "zip"
  source_file = "${path.module}/src/notifier.py"
  output_path = "${path.module}/build/secret-access-notifier.zip"
}

data "aws_iam_policy_document" "notifier_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "notifier" {
  count              = local.log_group_name != "" ? 1 : 0
  name               = "${var.project}-${var.environment}-secret-notifier-role-${var.aws_region}-01"
  assume_role_policy = data.aws_iam_policy_document.notifier_assume.json

  tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

data "aws_iam_policy_document" "notifier" {
  count = local.log_group_name != "" ? 1 : 0

  statement {
    sid       = "PublishAlert"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.secret_access.arn]
  }

  # Metadata only (tags/name) to classify the secret's environment - NOT GetSecretValue.
  statement {
    sid       = "DescribeSecretForEnvScope"
    actions   = ["secretsmanager:DescribeSecret"]
    resources = ["*"]
  }

  statement {
    sid       = "OwnLogs"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.notifier[0].arn}:*"]
  }
}

resource "aws_iam_role_policy" "notifier" {
  count  = local.log_group_name != "" ? 1 : 0
  name   = "${var.project}-${var.environment}-secret-notifier-policy"
  role   = aws_iam_role.notifier[0].id
  policy = data.aws_iam_policy_document.notifier[0].json
}

resource "aws_cloudwatch_log_group" "notifier" {
  count             = local.log_group_name != "" ? 1 : 0
  name              = "/aws/lambda/${local.notifier_name}"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "/aws/lambda/${local.notifier_name}"
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

resource "aws_lambda_function" "notifier" {
  count            = local.log_group_name != "" ? 1 : 0
  function_name    = local.notifier_name
  role             = aws_iam_role.notifier[0].arn
  runtime          = "python3.12"
  handler          = "notifier.handler"
  filename         = data.archive_file.notifier[0].output_path
  source_code_hash = data.archive_file.notifier[0].output_base64sha256
  timeout          = 10
  memory_size      = 128

  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.secret_access.arn
      ENVIRONMENT   = var.environment
    }
  }

  # Ensure the log group exists first (and is Terraform-managed with retention)
  # rather than being auto-created by the first invocation.
  depends_on = [aws_cloudwatch_log_group.notifier]

  tags = {
    Name        = local.notifier_name
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

resource "aws_lambda_permission" "logs_invoke" {
  count         = local.log_group_name != "" ? 1 : 0
  statement_id  = "AllowCloudWatchLogsInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.notifier[0].function_name
  principal     = "logs.${var.aws_region}.amazonaws.com"
  source_arn    = "${local.log_group_arn}:*"
}

resource "aws_cloudwatch_log_subscription_filter" "human_secret_access" {
  count           = local.log_group_name != "" ? 1 : 0
  name            = "${var.project}-${var.environment}-human-secret-access"
  log_group_name  = local.log_group_name
  filter_pattern  = local.human_get_secret_pattern
  destination_arn = aws_lambda_function.notifier[0].arn

  depends_on = [aws_lambda_permission.logs_invoke]
}
