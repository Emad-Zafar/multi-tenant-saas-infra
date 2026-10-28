# worker-autoscaler module outputs

output "lambda_function_name" {
  description = "Autoscaler Lambda function name"
  value       = aws_lambda_function.this.function_name
}

output "lambda_function_arn" {
  description = "Autoscaler Lambda ARN"
  value       = aws_lambda_function.this.arn
}

output "lambda_role_arn" {
  description = "Autoscaler Lambda execution role ARN"
  value       = aws_iam_role.lambda.arn
}

output "schedule_arn" {
  description = "EventBridge schedule ARN"
  value       = aws_scheduler_schedule.this.arn
}
