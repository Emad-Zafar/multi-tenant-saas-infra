# Security groups for the production ECS/ALB architecture.
#
# Traffic chain (least privilege, SG-to-SG references - matches the repo's existing
# RDS-from-EC2 pattern in modules/network):
#   internet --443--> ALB --container_port--> ECS --5432--> RDS
#                                                 \--6379--> Redis
#
# This SG set is SEPARATE from the interface-endpoint SG created in Phase 2
# (modules/vpc-endpoints).

# --- ALB: public-facing HTTPS ---
resource "aws_security_group" "alb" {
  name        = "${var.project}-${var.environment}-alb-sg"
  description = "ALB security group - inbound HTTPS from the internet"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.alb_ingress_cidr_blocks
  }

  # HTTP for the Phase 7 HTTP->HTTPS redirect listener.
  ingress {
    description = "HTTP from internet (redirected to HTTPS)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.alb_ingress_cidr_blocks
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project}-${var.environment}-alb-sg"
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

# --- ECS tasks: reachable only from the ALB ---
resource "aws_security_group" "ecs" {
  name        = "${var.project}-${var.environment}-ecs-sg"
  description = "ECS task security group - inbound only from the ALB on the container port"
  vpc_id      = var.vpc_id

  ingress {
    description     = "App traffic from ALB"
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "Allow all outbound traffic (DB, Redis, Secrets Manager, ECR, S3, logs via VPC endpoints / NAT)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project}-${var.environment}-ecs-sg"
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

# --- RDS: PostgreSQL only from the ECS tasks ---
resource "aws_security_group" "rds" {
  name        = "${var.project}-${var.environment}-rds-sg"
  description = "RDS security group - PostgreSQL only from ECS tasks"
  vpc_id      = var.vpc_id

  ingress {
    description     = "PostgreSQL from ECS tasks"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }

  # Optional: PostgreSQL from the RDS Proxy SG (added inline to avoid mixing inline
  # and standalone security_group_rule resources on this SG).
  dynamic "ingress" {
    for_each = var.rds_proxy_security_group_id != null ? [var.rds_proxy_security_group_id] : []
    content {
      description     = "PostgreSQL from RDS Proxy"
      from_port       = 5432
      to_port         = 5432
      protocol        = "tcp"
      security_groups = [ingress.value]
    }
  }

  # Optional: PostgreSQL from the CloudShell/admin DB-access SG (managed in code).
  dynamic "ingress" {
    for_each = var.rds_cloudshell_ingress_security_group_id != null ? [var.rds_cloudshell_ingress_security_group_id] : []
    content {
      description     = "PostgreSQL from CloudShell/admin access SG"
      from_port       = 5432
      to_port         = 5432
      protocol        = "tcp"
      security_groups = [ingress.value]
    }
  }

  # Optional: PostgreSQL from the worker SG (direct DB access after RDS Proxy removal).
  dynamic "ingress" {
    for_each = var.worker_security_group_id != null ? [var.worker_security_group_id] : []
    content {
      description     = "PostgreSQL from worker tasks"
      from_port       = 5432
      to_port         = 5432
      protocol        = "tcp"
      security_groups = [ingress.value]
    }
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project}-${var.environment}-rds-sg"
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

# --- Redis: ElastiCache only from the ECS tasks ---
resource "aws_security_group" "redis" {
  name        = "${var.project}-${var.environment}-redis-sg"
  description = "ElastiCache Redis security group - 6379 only from ECS tasks"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Redis from ECS tasks"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }

  # Optional: Redis from the worker SG (inline to avoid rule-resource conflicts).
  dynamic "ingress" {
    for_each = var.worker_security_group_id != null ? [var.worker_security_group_id] : []
    content {
      description     = "Redis from worker tasks"
      from_port       = 6379
      to_port         = 6379
      protocol        = "tcp"
      security_groups = [ingress.value]
    }
  }

  # Optional: Redis from the worker-autoscaler Lambda SG.
  dynamic "ingress" {
    for_each = var.autoscaler_security_group_id != null ? [var.autoscaler_security_group_id] : []
    content {
      description     = "Redis from worker-autoscaler Lambda"
      from_port       = 6379
      to_port         = 6379
      protocol        = "tcp"
      security_groups = [ingress.value]
    }
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project}-${var.environment}-redis-sg"
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}
