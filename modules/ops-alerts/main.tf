# Central ops-alerts pipeline.
#
#   CloudWatch alarms ─┐
#   (added next)       ├─▶ SNS topic (this) ─┬─▶ email subscribers (added/removed MANUALLY)
#   secret notifier   ─┘  + extra topics     └─▶ AWS Chatbot ─▶ Slack #saas-prod-alerts
#
# Email subscriptions are intentionally NOT managed here so the team can add/remove
# addresses in the console without Terraform reverting them.

# --- Central SNS topic all alarms publish to ---
resource "aws_sns_topic" "alerts" {
  name = "${var.project}-${var.environment}-alerts"

  tags = {
    Name        = "${var.project}-${var.environment}-alerts"
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

# --- IAM role AWS Chatbot assumes for this channel (read-only; can't run mutating ops) ---
data "aws_iam_policy_document" "chatbot_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["chatbot.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "chatbot" {
  name               = "${var.project}-${var.environment}-chatbot-role"
  assume_role_policy = data.aws_iam_policy_document.chatbot_assume.json

  tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

resource "aws_iam_role_policy_attachment" "chatbot_readonly" {
  role       = aws_iam_role.chatbot.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchReadOnlyAccess"
}

# --- Slack channel configuration ---
# Guardrail is read-only so nobody can run destructive AWS commands from Slack; this
# channel is for notifications, not ChatOps.
resource "aws_chatbot_slack_channel_configuration" "this" {
  configuration_name = "${var.project}-${var.environment}-alerts"
  iam_role_arn       = aws_iam_role.chatbot.arn
  slack_team_id      = var.slack_team_id
  slack_channel_id   = var.slack_channel_id

  sns_topic_arns = concat([aws_sns_topic.alerts.arn], var.extra_sns_topic_arns)

  logging_level         = "ERROR"
  guardrail_policy_arns = ["arn:aws:iam::aws:policy/CloudWatchReadOnlyAccess"]

  tags = {
    Name        = "${var.project}-${var.environment}-alerts"
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

# ---------------------------------------------------------------------------
# Raw alarms topic + formatter Lambda (plain-language rewrite -> clean topic)
# ---------------------------------------------------------------------------
# CloudWatch alarms publish here (raw). The formatter rewrites each into a
# readable sentence and republishes to the clean topic (email + Slack).
resource "aws_sns_topic" "alerts_raw" {
  name = "${var.project}-${var.environment}-alerts-raw"

  tags = {
    Name        = "${var.project}-${var.environment}-alerts-raw"
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

data "archive_file" "formatter" {
  type        = "zip"
  source_file = "${path.module}/src/formatter.py"
  output_path = "${path.module}/build/formatter.zip"
}

data "aws_iam_policy_document" "formatter_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "formatter" {
  name               = "${var.project}-${var.environment}-alert-formatter-role"
  assume_role_policy = data.aws_iam_policy_document.formatter_assume.json

  tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

resource "aws_cloudwatch_log_group" "formatter" {
  name              = "/aws/lambda/${var.project}-${var.environment}-alert-formatter"
  retention_in_days = 90

  tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

data "aws_iam_policy_document" "formatter" {
  statement {
    sid       = "PublishClean"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.alerts.arn]
  }
  statement {
    sid       = "OwnLogs"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.formatter.arn}:*"]
  }
}

resource "aws_iam_role_policy" "formatter" {
  name   = "${var.project}-${var.environment}-alert-formatter-policy"
  role   = aws_iam_role.formatter.id
  policy = data.aws_iam_policy_document.formatter.json
}

resource "aws_lambda_function" "formatter" {
  function_name    = "${var.project}-${var.environment}-alert-formatter"
  role             = aws_iam_role.formatter.arn
  runtime          = "python3.12"
  handler          = "formatter.handler"
  filename         = data.archive_file.formatter.output_path
  source_code_hash = data.archive_file.formatter.output_base64sha256
  timeout          = 10
  memory_size      = 128

  environment {
    variables = {
      CLEAN_TOPIC_ARN = aws_sns_topic.alerts.arn
      ENVIRONMENT     = var.environment
    }
  }

  depends_on = [aws_cloudwatch_log_group.formatter]

  tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

resource "aws_sns_topic_subscription" "formatter" {
  topic_arn = aws_sns_topic.alerts_raw.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.formatter.arn
}

resource "aws_lambda_permission" "raw_sns_invoke" {
  statement_id  = "AllowRawTopicInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.formatter.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.alerts_raw.arn
}
