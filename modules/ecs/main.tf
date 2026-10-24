# Prod API on ECS Fargate behind an internet-facing ALB.
# - Main task def: long-running API (SKIP_MIGRATIONS from plain env, no override).
# - Migration task def: same image, SKIP_MIGRATIONS stripped (runs master migrations).
# - Worker task def: SKIP_MIGRATIONS forced to "true" regardless of plain env (worker
#   never runs migrations).

locals {
  cluster_name = "${var.project}-${var.environment}-cluster"
  service_name = "${var.project}-${var.environment}-api"
  family_main  = "${var.project}-${var.environment}-api"
  family_migr  = "${var.project}-${var.environment}-api-migrate"

  # DB_HOST override (e.g. RDS Proxy) applied to the API + worker tasks.
  db_host_env = var.db_host != "" ? merge(var.plain_environment, { DB_HOST = var.db_host }) : var.plain_environment

  # Main (API) task: proxy DB_HOST + PROCESS_ROLE=api.
  main_env_map = merge(local.db_host_env, { PROCESS_ROLE = "api" })
  main_env     = [for k, v in local.main_env_map : { name = k, value = v }]

  # Migration task uses plain_environment as-is (direct RDS DB_HOST), minus the
  # migration-only exclusions. Not routed through the proxy, no PROCESS_ROLE.
  migration_env = [for k, v in var.plain_environment : { name = k, value = v } if !contains(["SKIP_MIGRATIONS", "AUTO_SEED"], k)]

  # Worker task: proxy DB_HOST + PROCESS_ROLE=worker, AUTO_SEED stripped,
  # SKIP_MIGRATIONS pinned to "true" (worker never runs migrations).
  worker_env_map = merge(
    { for k, v in local.db_host_env : k => v if k != "AUTO_SEED" },
    { PROCESS_ROLE = "worker", SKIP_MIGRATIONS = "true" },
  )
  worker_env = [for k, v in local.worker_env_map : { name = k, value = v }]

  worker_subnet_ids = length(var.worker_subnet_ids) > 0 ? var.worker_subnet_ids : (length(var.service_subnet_ids) > 0 ? var.service_subnet_ids : var.private_subnet_ids)

  # Each secret env var pulls one top-level JSON key from the bundled app secret.
  secrets = [for env_name, json_key in var.container_secrets : {
    name      = env_name
    valueFrom = "${var.app_secret_arn}:${json_key}::"
  }]
}

resource "aws_ecs_cluster" "this" {
  name = local.cluster_name

  setting {
    name  = "containerInsights"
    value = var.container_insights
  }

  tags = {
    Name        = local.cluster_name
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

resource "aws_cloudwatch_log_group" "api" {
  name              = "/ecs/${local.family_main}"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "/ecs/${local.family_main}"
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

# --- Main (long-running API) task definition ---
resource "aws_ecs_task_definition" "main" {
  family                   = local.family_main
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode([
    {
      name      = "api"
      image     = var.container_image
      essential = true
      portMappings = [
        { containerPort = var.container_port, protocol = "tcp" }
      ]
      environment = local.main_env
      secrets     = local.secrets
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.api.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "api"
        }
      }
    }
  ])

  tags = {
    Name        = local.family_main
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

# --- One-off migration task definition (master migrations only) ---
resource "aws_ecs_task_definition" "migration" {
  family                   = local.family_migr
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode([
    {
      name        = "migrate"
      image       = var.container_image
      essential   = true
      environment = local.migration_env # SKIP_MIGRATIONS stripped; AUTO_SEED unset
      secrets     = local.secrets
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.api.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "migration"
        }
      }
    }
  ])

  tags = {
    Name        = local.family_migr
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

# --- ALB ---
resource "aws_lb" "this" {
  name               = "${var.project}-${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets            = var.public_subnet_ids

  tags = {
    Name        = "${var.project}-${var.environment}-alb"
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

resource "aws_lb_target_group" "this" {
  name        = "${var.project}-${var.environment}-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip" # Fargate awsvpc

  health_check {
    path                = var.health_check_path
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Name        = "${var.project}-${var.environment}-tg"
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

# HTTP :80 -> redirect to HTTPS :443
resource "aws_lb_listener" "http_redirect" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# HTTPS :443 -> forward to the API target group
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = var.ssl_policy
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}

# --- ECS service ---
resource "aws_ecs_service" "this" {
  name            = local.service_name
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.main.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = length(var.service_subnet_ids) > 0 ? var.service_subnet_ids : var.private_subnet_ids
    security_groups  = [var.ecs_security_group_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.this.arn
    container_name   = "api"
    container_port   = var.container_port
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  tags = {
    Name        = local.service_name
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }

  # desired_count is owned by autoscaling / manual scale-up after migrations.
  # task_definition is owned by the CI pipeline, which registers a new revision each
  # deploy - Terraform must not roll it back to the revision recorded in state.
  lifecycle {
    ignore_changes = [desired_count, task_definition]
  }

  depends_on = [aws_lb_listener.https]
}

# --- Autoscaling (target tracking on CPU) ---
resource "aws_appautoscaling_target" "ecs" {
  max_capacity       = var.max_capacity
  min_capacity       = var.min_capacity
  resource_id        = "service/${aws_ecs_cluster.this.name}/${aws_ecs_service.this.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "cpu" {
  name               = "${var.project}-${var.environment}-api-cpu-target"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = var.cpu_target_value
  }
}

# ---------------------------------------------------------------------------
# Worker tier (same image, PROCESS_ROLE=worker, no load balancer)
# ---------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "worker" {
  count             = var.enable_worker ? 1 : 0
  name              = "/ecs/${var.project}-${var.environment}-worker"
  retention_in_days = var.worker_log_retention_days

  tags = {
    Name        = "/ecs/${var.project}-${var.environment}-worker"
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

resource "aws_ecs_task_definition" "worker" {
  count                    = var.enable_worker ? 1 : 0
  family                   = "${var.project}-${var.environment}-worker"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.worker_cpu
  memory                   = var.worker_memory
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode([
    {
      name        = "worker"
      image       = var.container_image
      essential   = true
      stopTimeout = var.worker_stop_timeout
      environment = local.worker_env
      secrets     = local.secrets
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.worker[0].name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "worker"
        }
      }
    }
  ])

  tags = {
    Name        = "${var.project}-${var.environment}-worker"
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

resource "aws_ecs_service" "worker" {
  count           = var.enable_worker ? 1 : 0
  name            = "${var.project}-${var.environment}-worker"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.worker[0].arn
  desired_count   = var.worker_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = local.worker_subnet_ids
    security_groups  = [var.worker_security_group_id]
    assign_public_ip = false
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  tags = {
    Name        = "${var.project}-${var.environment}-worker"
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }

  # desired_count owned by the autoscaler / manual scaling.
  # task_definition owned by the CI pipeline (new revision each deploy) - do not roll back.
  lifecycle {
    ignore_changes = [desired_count, task_definition]
  }
}
