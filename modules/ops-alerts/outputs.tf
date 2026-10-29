# ops-alerts module outputs

output "alerts_topic_arn" {
  description = "ARN of the central alerts SNS topic (point CloudWatch alarm_actions here)"
  value       = aws_sns_topic.alerts.arn
}

output "chatbot_configuration_arn" {
  description = "ARN of the Slack channel configuration"
  value       = aws_chatbot_slack_channel_configuration.this.chat_configuration_arn
}

output "raw_topic_arn" {
  description = "SNS topic CloudWatch alarms publish to (formatter rewrites -> clean topic)"
  value       = aws_sns_topic.alerts_raw.arn
}
