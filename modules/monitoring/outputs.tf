# monitoring module outputs

output "alarm_names" {
  description = "All CloudWatch alarm names created by this module"
  value = concat(
    [
      aws_cloudwatch_metric_alarm.api_unhealthy.alarm_name,
      aws_cloudwatch_metric_alarm.alb_5xx.alarm_name,
      aws_cloudwatch_metric_alarm.target_5xx.alarm_name,
      aws_cloudwatch_metric_alarm.target_4xx.alarm_name,
      aws_cloudwatch_metric_alarm.request_spike.alarm_name,
      aws_cloudwatch_metric_alarm.latency_p95.alarm_name,
      aws_cloudwatch_metric_alarm.ecs_cpu.alarm_name,
      aws_cloudwatch_metric_alarm.ecs_memory.alarm_name,
      aws_cloudwatch_metric_alarm.rds_free_storage.alarm_name,
      aws_cloudwatch_metric_alarm.rds_cpu.alarm_name,
      aws_cloudwatch_metric_alarm.rds_connections.alarm_name,
      aws_cloudwatch_metric_alarm.redis_cpu.alarm_name,
      aws_cloudwatch_metric_alarm.redis_memory.alarm_name,
    ],
    [for a in aws_cloudwatch_metric_alarm.lambda_errors : a.alarm_name],
  )
}
