# Prod master/registry PostgreSQL.
# Per-tenant databases are created at RUNTIME by the app (CREATEDB) on this instance -
# Terraform only provisions the instance + the master/registry database.

resource "aws_db_subnet_group" "this" {
  name       = "${var.project}-${var.environment}-rds-subnet-group-${var.aws_region}-01"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name        = "${var.project}-${var.environment}-rds-subnet-group-${var.aws_region}-01"
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

resource "aws_db_instance" "this" {
  identifier            = var.db_instance_identifier
  engine                = "postgres"
  engine_version        = var.db_engine_version
  instance_class        = var.db_instance_class
  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_max_allocated_storage
  storage_type          = "gp3"

  # CMK-encrypted storage + RDS-managed master password (also CMK-encrypted).
  storage_encrypted             = true
  kms_key_id                    = var.kms_key_id
  manage_master_user_password   = true
  master_user_secret_kms_key_id = var.kms_key_id

  db_name  = var.db_name
  username = var.db_username

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [var.rds_security_group_id]
  parameter_group_name   = var.db_parameter_group_name

  publicly_accessible = false
  multi_az            = var.multi_az

  # Automated backups (>0 days) enable point-in-time recovery.
  backup_retention_period = var.backup_retention_period
  backup_window           = var.backup_window
  maintenance_window      = var.maintenance_window
  copy_tags_to_snapshot   = true

  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = false
  final_snapshot_identifier = "${var.db_instance_identifier}-final-snapshot"

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  performance_insights_enabled    = false

  tags = {
    Name        = var.db_instance_identifier
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}
