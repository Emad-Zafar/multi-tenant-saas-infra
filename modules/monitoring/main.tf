# CloudWatch alarms for the prod stack. Every alarm notifies the central alerts
# topic (ALARM + OK) -> email + Slack. Thresholds are variables; tune to real traffic.

locals {
  prefix = "${var.project}-${var.environment}"
  actions = {
    alarm = [var.alarms_topic_arn]
    ok    = [var.alarms_topic_arn]
  }
  tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

# ===========================================================================
# ALB / API  (AWS/ApplicationELB)
# ===========================================================================

# P1 - no healthy API targets = outage. Missing data (no targets) is breaching.
resource "aws_cloudwatch_metric_alarm" "api_unhealthy" {
  alarm_name          = "${local.prefix}-alb-no-healthy-hosts"
  alarm_description   = "P1: ALB has no healthy API targets - the API is down."
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HealthyHostCount"
  statistic           = "Minimum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 1
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "breaching"
  dimensions          = { LoadBalancer = var.alb_arn_suffix, TargetGroup = var.target_group_arn_suffix }
  alarm_actions       = local.actions.alarm
  ok_actions          = local.actions.ok
  tags                = local.tags
}

# P1 - load-balancer-level 5xx (502/503/504: no healthy targets, timeouts).
resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "${local.prefix}-alb-elb-5xx"
  alarm_description   = "P1: ALB is returning 5xx (load-balancer level)."
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_ELB_5XX_Count"
  statistic           = "Sum"
  period              = var.period_seconds
  evaluation_periods  = 1
  threshold           = var.alb_5xx_threshold
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  dimensions          = { LoadBalancer = var.alb_arn_suffix }
  alarm_actions       = local.actions.alarm
  ok_actions          = local.actions.ok
  tags                = local.tags
}

# P1 - application 5xx (the API itself is erroring).
resource "aws_cloudwatch_metric_alarm" "target_5xx" {
  alarm_name          = "${local.prefix}-alb-target-5xx"
  alarm_description   = "P1: the API (target) is returning 5xx."
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_Target_5XX_Count"
  statistic           = "Sum"
  period              = var.period_seconds
  evaluation_periods  = 1
  threshold           = var.alb_5xx_threshold
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  dimensions          = { LoadBalancer = var.alb_arn_suffix, TargetGroup = var.target_group_arn_suffix }
  alarm_actions       = local.actions.alarm
  ok_actions          = local.actions.ok
  tags                = local.tags
}

# P2 - client-error surge (misuse / abuse / broken client).
resource "aws_cloudwatch_metric_alarm" "target_4xx" {
  alarm_name          = "${local.prefix}-alb-target-4xx-surge"
  alarm_description   = "P2: elevated 4xx from the API (abuse/misuse or a broken client)."
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_Target_4XX_Count"
  statistic           = "Sum"
  period              = var.period_seconds
  evaluation_periods  = 1
  threshold           = var.alb_4xx_threshold
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  dimensions          = { LoadBalancer = var.alb_arn_suffix, TargetGroup = var.target_group_arn_suffix }
  alarm_actions       = local.actions.alarm
  ok_actions          = local.actions.ok
  tags                = local.tags
}

# P2 - traffic spike ("too many API calls").
resource "aws_cloudwatch_metric_alarm" "request_spike" {
  alarm_name          = "${local.prefix}-alb-request-spike"
  alarm_description   = "P2: unusually high request volume (possible spike/abuse)."
  namespace           = "AWS/ApplicationELB"
  metric_name         = "RequestCount"
  statistic           = "Sum"
  period              = var.period_seconds
  evaluation_periods  = 1
  threshold           = var.alb_request_count_threshold
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  dimensions          = { LoadBalancer = var.alb_arn_suffix }
  alarm_actions       = local.actions.alarm
  ok_actions          = local.actions.ok
  tags                = local.tags
}

# P2 - latency (p95 response time).
resource "aws_cloudwatch_metric_alarm" "latency_p95" {
  alarm_name          = "${local.prefix}-alb-latency-p95"
  alarm_description   = "P2: API p95 response time is high."
  namespace           = "AWS/ApplicationELB"
  metric_name         = "TargetResponseTime"
  extended_statistic  = "p95"
  period              = var.period_seconds
  evaluation_periods  = 1
  threshold           = var.alb_p95_latency_seconds
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  dimensions          = { LoadBalancer = var.alb_arn_suffix, TargetGroup = var.target_group_arn_suffix }
  alarm_actions       = local.actions.alarm
  ok_actions          = local.actions.ok
  tags                = local.tags
}

# ===========================================================================
# ECS API service  (AWS/ECS)
# ===========================================================================

resource "aws_cloudwatch_metric_alarm" "ecs_cpu" {
  alarm_name          = "${local.prefix}-ecs-api-cpu-high"
  alarm_description   = "P2: API ECS service CPU utilization high."
  namespace           = "AWS/ECS"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = var.period_seconds
  evaluation_periods  = 1
  threshold           = var.ecs_cpu_threshold
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  dimensions          = { ClusterName = var.ecs_cluster_name, ServiceName = var.ecs_service_name }
  alarm_actions       = local.actions.alarm
  ok_actions          = local.actions.ok
  tags                = local.tags
}

resource "aws_cloudwatch_metric_alarm" "ecs_memory" {
  alarm_name          = "${local.prefix}-ecs-api-memory-high"
  alarm_description   = "P2: API ECS service memory utilization high."
  namespace           = "AWS/ECS"
  metric_name         = "MemoryUtilization"
  statistic           = "Average"
  period              = var.period_seconds
  evaluation_periods  = 1
  threshold           = var.ecs_memory_threshold
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  dimensions          = { ClusterName = var.ecs_cluster_name, ServiceName = var.ecs_service_name }
  alarm_actions       = local.actions.alarm
  ok_actions          = local.actions.ok
  tags                = local.tags
}

# ===========================================================================
# RDS  (AWS/RDS)
# ===========================================================================

# P1 - running out of disk.
resource "aws_cloudwatch_metric_alarm" "rds_free_storage" {
  alarm_name          = "${local.prefix}-rds-free-storage-low"
  alarm_description   = "P1: RDS free storage is low."
  namespace           = "AWS/RDS"
  metric_name         = "FreeStorageSpace"
  statistic           = "Average"
  period              = var.period_seconds
  evaluation_periods  = 1
  threshold           = var.rds_free_storage_bytes
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "notBreaching"
  dimensions          = { DBInstanceIdentifier = var.rds_instance_id }
  alarm_actions       = local.actions.alarm
  ok_actions          = local.actions.ok
  tags                = local.tags
}

resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  alarm_name          = "${local.prefix}-rds-cpu-high"
  alarm_description   = "P2: RDS CPU utilization high."
  namespace           = "AWS/RDS"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = var.period_seconds
  evaluation_periods  = 1
  threshold           = var.rds_cpu_threshold
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  dimensions          = { DBInstanceIdentifier = var.rds_instance_id }
  alarm_actions       = local.actions.alarm
  ok_actions          = local.actions.ok
  tags                = local.tags
}

resource "aws_cloudwatch_metric_alarm" "rds_connections" {
  alarm_name          = "${local.prefix}-rds-connections-high"
  alarm_description   = "P2: RDS open connections are high (near pool/instance limit)."
  namespace           = "AWS/RDS"
  metric_name         = "DatabaseConnections"
  statistic           = "Average"
  period              = var.period_seconds
  evaluation_periods  = 1
  threshold           = var.rds_connections_threshold
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  dimensions          = { DBInstanceIdentifier = var.rds_instance_id }
  alarm_actions       = local.actions.alarm
  ok_actions          = local.actions.ok
  tags                = local.tags
}

# ===========================================================================
# Redis / ElastiCache  (AWS/ElastiCache)
# ===========================================================================

resource "aws_cloudwatch_metric_alarm" "redis_cpu" {
  alarm_name          = "${local.prefix}-redis-cpu-high"
  alarm_description   = "P2: Redis engine CPU utilization high."
  namespace           = "AWS/ElastiCache"
  metric_name         = "EngineCPUUtilization"
  statistic           = "Average"
  period              = var.period_seconds
  evaluation_periods  = 1
  threshold           = var.redis_cpu_threshold
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  dimensions          = { CacheClusterId = var.redis_node_id }
  alarm_actions       = local.actions.alarm
  ok_actions          = local.actions.ok
  tags                = local.tags
}

resource "aws_cloudwatch_metric_alarm" "redis_memory" {
  alarm_name          = "${local.prefix}-redis-memory-high"
  alarm_description   = "P2: Redis memory usage high (eviction risk)."
  namespace           = "AWS/ElastiCache"
  metric_name         = "DatabaseMemoryUsagePercentage"
  statistic           = "Average"
  period              = var.period_seconds
  evaluation_periods  = 1
  threshold           = var.redis_memory_threshold
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  dimensions          = { CacheClusterId = var.redis_node_id }
  alarm_actions       = local.actions.alarm
  ok_actions          = local.actions.ok
  tags                = local.tags
}

# ===========================================================================
# Lambda errors  (AWS/Lambda) - one per supplied function
# ===========================================================================

resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  for_each            = var.lambda_function_names
  alarm_name          = "${local.prefix}-lambda-${each.key}-errors"
  alarm_description   = "P2: Lambda ${each.value} is erroring."
  namespace           = "AWS/Lambda"
  metric_name         = "Errors"
  statistic           = "Sum"
  period              = var.period_seconds
  evaluation_periods  = 1
  threshold           = var.lambda_error_threshold
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  dimensions          = { FunctionName = each.value }
  alarm_actions       = local.actions.alarm
  ok_actions          = local.actions.ok
  tags                = local.tags
}

# ===========================================================================
# ECS crash-loop  (EventBridge task-stopped -> Lambda -> custom metric -> alarm)
# ===========================================================================

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  cluster_arn = "arn:aws:ecs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:cluster/${var.ecs_cluster_name}"
}

data "archive_file" "crashloop" {
  type        = "zip"
  source_file = "${path.module}/src/crashloop.py"
  output_path = "${path.module}/build/crashloop.zip"
}

data "aws_iam_policy_document" "crashloop_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "crashloop" {
  name               = "${local.prefix}-crashloop-role"
  assume_role_policy = data.aws_iam_policy_document.crashloop_assume.json
  tags               = local.tags
}

resource "aws_cloudwatch_log_group" "crashloop" {
  name              = "/aws/lambda/${local.prefix}-crashloop"
  retention_in_days = 90
  tags              = local.tags
}

data "aws_iam_policy_document" "crashloop" {
  statement {
    sid       = "PutMetric"
    actions   = ["cloudwatch:PutMetricData"]
    resources = ["*"] # PutMetricData does not support resource scoping
  }
  statement {
    sid       = "OwnLogs"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.crashloop.arn}:*"]
  }
}

resource "aws_iam_role_policy" "crashloop" {
  name   = "${local.prefix}-crashloop-policy"
  role   = aws_iam_role.crashloop.id
  policy = data.aws_iam_policy_document.crashloop.json
}

resource "aws_lambda_function" "crashloop" {
  function_name    = "${local.prefix}-crashloop"
  role             = aws_iam_role.crashloop.arn
  runtime          = "python3.12"
  handler          = "crashloop.handler"
  filename         = data.archive_file.crashloop.output_path
  source_code_hash = data.archive_file.crashloop.output_base64sha256
  timeout          = 10
  memory_size      = 128
  environment {
    variables = { CLUSTER_NAME = var.ecs_cluster_name }
  }
  depends_on = [aws_cloudwatch_log_group.crashloop]
  tags       = local.tags
}

# Only genuine crashes in the PROD cluster (not scale-in stops, not dev/stg).
resource "aws_cloudwatch_event_rule" "ecs_task_crash" {
  name        = "${local.prefix}-ecs-task-crash"
  description = "ECS task crashes (essential container exited / failed to start) in the prod cluster"
  event_pattern = jsonencode({
    source      = ["aws.ecs"]
    detail-type = ["ECS Task State Change"]
    detail = {
      clusterArn = [local.cluster_arn]
      lastStatus = ["STOPPED"]
      stopCode   = ["EssentialContainerExited", "TaskFailedToStart"]
    }
  })
  tags = local.tags
}

resource "aws_cloudwatch_event_target" "crashloop" {
  rule      = aws_cloudwatch_event_rule.ecs_task_crash.name
  target_id = "crashloop-lambda"
  arn       = aws_lambda_function.crashloop.arn
}

resource "aws_lambda_permission" "events_crashloop" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.crashloop.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.ecs_task_crash.arn
}

resource "aws_cloudwatch_metric_alarm" "crash_loop" {
  alarm_name          = "${local.prefix}-ecs-crash-loop"
  alarm_description   = "P1: ECS tasks are crash-looping (repeated crashes in a short window)."
  namespace           = "SaaS/ECS"
  metric_name         = "TaskCrash"
  statistic           = "Sum"
  period              = var.period_seconds
  evaluation_periods  = 1
  threshold           = var.crash_loop_threshold
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  dimensions          = { ClusterName = var.ecs_cluster_name }
  alarm_actions       = local.actions.alarm
  ok_actions          = local.actions.ok
  tags                = local.tags
}
