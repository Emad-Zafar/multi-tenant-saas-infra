# Inputs for the ops-alerts module (central alert SNS topic + Slack via AWS Chatbot).

variable "project" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "slack_team_id" {
  description = "Slack workspace (team) ID from AWS Chatbot authorization, e.g. T0XXXXXXX."
  type        = string
}

variable "slack_channel_id" {
  description = "Slack channel ID the alerts post to, e.g. C0XXXXXXX."
  type        = string
}

variable "extra_sns_topic_arns" {
  description = "Additional existing SNS topic ARNs Chatbot should also forward to this channel (e.g. the secret-access topic)."
  type        = list(string)
  default     = []
}
