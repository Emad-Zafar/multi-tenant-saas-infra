# ECS + ALB module outputs

output "cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.this.name
}

output "service_name" {
  description = "ECS service name"
  value       = aws_ecs_service.this.name
}

output "alb_dns_name" {
  description = "ALB DNS name"
  value       = aws_lb.this.dns_name
}

output "alb_zone_id" {
  description = "ALB hosted zone ID (for Route 53 alias)"
  value       = aws_lb.this.zone_id
}

output "alb_arn" {
  description = "ALB ARN"
  value       = aws_lb.this.arn
}

output "target_group_arn" {
  description = "Target group ARN"
  value       = aws_lb_target_group.this.arn
}

output "main_task_definition_arn" {
  description = "Main API task definition ARN"
  value       = aws_ecs_task_definition.main.arn
}

output "migration_task_definition_arn" {
  description = "One-off migration task definition ARN"
  value       = aws_ecs_task_definition.migration.arn
}

output "log_group_name" {
  description = "CloudWatch log group name"
  value       = aws_cloudwatch_log_group.api.name
}

output "worker_service_name" {
  description = "Worker ECS service name (null if disabled)"
  value       = try(aws_ecs_service.worker[0].name, null)
}

output "worker_task_definition_arn" {
  description = "Worker task definition ARN (null if disabled)"
  value       = try(aws_ecs_task_definition.worker[0].arn, null)
}

output "alb_arn_suffix" {
  description = "ALB ARN suffix for CloudWatch LoadBalancer dimension"
  value       = aws_lb.this.arn_suffix
}

output "target_group_arn_suffix" {
  description = "Target group ARN suffix for CloudWatch TargetGroup dimension"
  value       = aws_lb_target_group.this.arn_suffix
}
