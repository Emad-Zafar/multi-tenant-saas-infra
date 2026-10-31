# Worker tier security group.
# Created at the root (not inside a module) so it can be referenced by the ecs,
# security-groups, and rds-proxy modules without creating a module dependency cycle.
# Zero inbound rules; egress all.

resource "aws_security_group" "worker" {
  name        = "${var.project}-${var.environment}-worker-sg"
  description = "Worker tasks security group - no inbound, egress all"
  vpc_id      = module.network.vpc_id

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project}-${var.environment}-worker-sg"
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

# Worker-autoscaler Lambda security group (created at the root to avoid a module cycle
# with the cache/security-groups modules). Egress all (reaches Redis + ECS API via NAT).
resource "aws_security_group" "autoscaler_lambda" {
  name        = "${var.project}-${var.environment}-autoscaler-sg"
  description = "Worker-autoscaler Lambda SG - egress all"
  vpc_id      = module.network.vpc_id

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project}-${var.environment}-autoscaler-sg"
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}
