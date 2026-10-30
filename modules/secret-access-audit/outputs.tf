# Secret-Access Audit module outputs

output "sns_topic_arn" {
  description = "ARN of the SNS topic the human-secret-access alarm publishes to"
  value       = aws_sns_topic.secret_access.arn
}

output "cloudtrail_arn" {
  description = "ARN of the CloudTrail (null if create_cloudtrail = false)"
  value       = try(aws_cloudtrail.this[0].arn, null)
}

output "cloudtrail_log_group_name" {
  description = "Name of the CloudWatch Logs group the metric filter is attached to"
  value       = local.log_group_name
}

output "secret_access_notifier_lambda_name" {
  description = "Name of the human-secret-access notifier Lambda (null if no log group)"
  value       = try(aws_lambda_function.notifier[0].function_name, null)
}
