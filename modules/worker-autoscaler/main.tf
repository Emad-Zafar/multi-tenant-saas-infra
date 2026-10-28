# Worker autoscaler: Node.js Lambda on a 1-minute EventBridge Scheduler that scales
# the ECS worker service on BullMQ queue depth.

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  account_id   = data.aws_caller_identity.current.account_id
  partition    = data.aws_partition.current.partition
  name         = "${var.project}-${var.environment}-worker-autoscaler"
  service_arn  = "arn:${local.partition}:ecs:${var.aws_region}:${local.account_id}:service/${var.cluster_name}/${var.service_name}"
  src_dir      = "${path.module}/src"
  package_path = "${path.module}/build/worker-autoscaler.zip"
}

# Build step: install runtime deps (bullmq, ioredis) into src/node_modules before zipping.
# Requires Node/npm on the apply runner.
resource "null_resource" "build" {
  triggers = {
    package = filemd5("${local.src_dir}/package.json")
    index   = filemd5("${local.src_dir}/index.js")
  }

  provisioner "local-exec" {
    command     = "npm install --omit=dev --no-audit --no-fund"
    working_dir = local.src_dir
  }
}

data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = local.src_dir
  output_path = local.package_path
  depends_on  = [null_resource.build]
}

# --- Lambda IAM role ---
data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  name               = "${local.name}-role"
  assume_role_policy = data.aws_iam_policy_document.assume.json

  tags = {
    Name        = "${local.name}-role"
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

# VPC ENI management + CloudWatch Logs (AWS managed).
resource "aws_iam_role_policy_attachment" "vpc" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:${local.partition}:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Scale only the worker service.
data "aws_iam_policy_document" "ecs" {
  statement {
    sid       = "ScaleWorkerService"
    actions   = ["ecs:UpdateService", "ecs:DescribeServices"]
    resources = [local.service_arn]
  }
}

resource "aws_iam_role_policy" "ecs" {
  name   = "${local.name}-ecs"
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.ecs.json
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${local.name}"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "/aws/lambda/${local.name}"
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

# --- Lambda ---
resource "aws_lambda_function" "this" {
  function_name    = local.name
  role             = aws_iam_role.lambda.arn
  runtime          = "nodejs20.x"
  handler          = "index.handler"
  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256
  timeout          = var.lambda_timeout
  memory_size      = var.lambda_memory

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = var.security_group_ids
  }

  environment {
    variables = {
      REDIS_HOST       = var.redis_host
      REDIS_PORT       = "6379"
      CLUSTER          = var.cluster_name
      SERVICE          = var.service_name
      T_WORKER_PER_MIN = tostring(var.t_worker_per_min)
      D_SECONDS        = tostring(var.d_seconds)
      N_MIN            = tostring(var.n_min)
      N_MAX            = tostring(var.n_max)
      EXCLUDE_QUEUES   = var.exclude_queues
    }
  }

  depends_on = [aws_iam_role_policy_attachment.vpc, aws_cloudwatch_log_group.lambda]

  tags = {
    Name        = local.name
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

# --- EventBridge Scheduler (every 1 minute) ---
data "aws_iam_policy_document" "scheduler_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["scheduler.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "scheduler" {
  name               = "${local.name}-scheduler-role"
  assume_role_policy = data.aws_iam_policy_document.scheduler_assume.json

  tags = {
    Name        = "${local.name}-scheduler-role"
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

data "aws_iam_policy_document" "scheduler" {
  statement {
    actions   = ["lambda:InvokeFunction"]
    resources = [aws_lambda_function.this.arn]
  }
}

resource "aws_iam_role_policy" "scheduler" {
  name   = "${local.name}-scheduler"
  role   = aws_iam_role.scheduler.id
  policy = data.aws_iam_policy_document.scheduler.json
}

resource "aws_scheduler_schedule" "this" {
  name = local.name

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression = var.schedule_expression

  target {
    arn      = aws_lambda_function.this.arn
    role_arn = aws_iam_role.scheduler.arn
  }
}
