# RDS Proxy for the prod PostgreSQL instance.
# Connection pooling + a single stable endpoint in front of db-postgresql-saas-prod.

data "aws_partition" "current" {}

# Read the app DB credentials out of the existing bundle to mint a proxy-format secret.
# NOTE: this reads the secret value at plan/apply time -> it lands in Terraform state
# (encrypted in the S3 backend). Required to build the {username,password} secret.
data "aws_secretsmanager_secret_version" "app" {
  secret_id = var.app_secret_name
}

locals {
  app_creds = jsondecode(data.aws_secretsmanager_secret_version.app.secret_string)
  db_user   = local.app_creds[var.app_secret_username_key]
  db_pass   = local.app_creds[var.app_secret_password_key]
}

# New dedicated secret in the {username, password} shape RDS Proxy expects.
resource "aws_secretsmanager_secret" "proxy" {
  name       = var.proxy_secret_name
  kms_key_id = var.kms_key_arn

  tags = {
    Name        = var.proxy_secret_name
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

resource "aws_secretsmanager_secret_version" "proxy" {
  secret_id = aws_secretsmanager_secret.proxy.id
  secret_string = jsonencode({
    username = local.db_user
    password = local.db_pass
  })
}

# Proxy security group: inbound 5432 from the ECS tasks only.
resource "aws_security_group" "proxy" {
  name        = "${var.project}-${var.environment}-proxy-sg"
  description = "RDS Proxy security group - 5432 from ECS tasks"
  vpc_id      = var.vpc_id

  ingress {
    description     = "PostgreSQL from ECS tasks"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.ecs_security_group_id]
  }

  # Optional: PostgreSQL from the worker SG (inline to avoid rule-resource conflicts).
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
    Name        = "${var.project}-${var.environment}-proxy-sg"
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

# IAM role the proxy assumes to read its secret + decrypt via the CMK.
data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["rds.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "proxy" {
  name               = "${var.project}-${var.environment}-proxy-role-${var.aws_region}-01"
  assume_role_policy = data.aws_iam_policy_document.assume.json

  tags = {
    Name        = "${var.project}-${var.environment}-proxy-role-${var.aws_region}-01"
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

data "aws_iam_policy_document" "proxy" {
  statement {
    sid       = "ReadProxySecret"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_secretsmanager_secret.proxy.arn]
  }
  statement {
    sid       = "DecryptWithCmk"
    actions   = ["kms:Decrypt"]
    resources = [var.kms_key_arn]
  }
}

resource "aws_iam_role_policy" "proxy" {
  name   = "${var.project}-${var.environment}-proxy-policy"
  role   = aws_iam_role.proxy.id
  policy = data.aws_iam_policy_document.proxy.json
}

# The proxy.
resource "aws_db_proxy" "this" {
  name                   = "${var.project}-${var.environment}-proxy"
  engine_family          = "POSTGRESQL"
  require_tls            = var.require_tls
  role_arn               = aws_iam_role.proxy.arn
  vpc_subnet_ids         = var.subnet_ids
  vpc_security_group_ids = [aws_security_group.proxy.id]

  auth {
    auth_scheme = "SECRETS"
    iam_auth    = "DISABLED"
    secret_arn  = aws_secretsmanager_secret.proxy.arn
  }

  tags = {
    Name        = "${var.project}-${var.environment}-proxy"
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

# Default target group (keep pooling defaults) + register the RDS instance.
resource "aws_db_proxy_default_target_group" "this" {
  db_proxy_name = aws_db_proxy.this.name
}

resource "aws_db_proxy_target" "this" {
  db_proxy_name          = aws_db_proxy.this.name
  target_group_name      = aws_db_proxy_default_target_group.this.name
  db_instance_identifier = var.db_instance_identifier
}
