# DB Subnet Group for RDS
resource "aws_db_subnet_group" "saas_rds_subnet_group" {
  name       = "${var.project}-${var.environment}-rds-subnet-group-${var.aws_region}-01"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name        = "${var.project}-${var.environment}-rds-subnet-group-${var.aws_region}-01"
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

# RDS PostgreSQL Instance with Secrets Manager password management
resource "aws_db_instance" "saas_postgres" {
  identifier            = var.db_instance_identifier
  engine                = "postgres"
  engine_version        = var.db_engine_version # AWS will use the latest available version matching the prefix
  instance_class        = var.db_instance_class
  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_max_allocated_storage
  storage_type          = "gp3" # More cost-effective than gp2
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.db_username

  # Use AWS Secrets Manager for password management (most secure)
  manage_master_user_password   = true
  master_user_secret_kms_key_id = var.kms_key_id

  db_subnet_group_name   = aws_db_subnet_group.saas_rds_subnet_group.name
  vpc_security_group_ids = [var.rds_security_group_id]

  # DB Parameter Group
  parameter_group_name = var.db_parameter_group_name

  publicly_accessible     = false
  multi_az                = false
  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "mon:04:00-mon:05:00"

  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.project}-${var.environment}-postgres-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  performance_insights_enabled = false
  deletion_protection          = false

  tags = {
    Name        = var.db_instance_identifier
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

# S3 Bucket for static images and data storage
resource "aws_s3_bucket" "saas_storage" {
  bucket = var.s3_bucket_name

  tags = {
    Name        = var.s3_bucket_name
    Environment = var.environment
    Project     = var.project
    Purpose     = "SaaS static images and data storage"
    ManagedBy   = "Terraform"
  }
}

# S3 Bucket Versioning (Disabled as per requirements)
resource "aws_s3_bucket_versioning" "saas_storage" {
  bucket = aws_s3_bucket.saas_storage.id

  versioning_configuration {
    status = "Suspended"
  }
}

# S3 Bucket Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "saas_storage" {
  bucket = aws_s3_bucket.saas_storage.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# S3 Bucket Public Access Block (restrict public access by default)
resource "aws_s3_bucket_public_access_block" "saas_storage" {
  bucket = aws_s3_bucket.saas_storage.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 Bucket Policy for EC2 IAM Role access
# Note: Policy is always created since IAM role is always created by IAM module
resource "aws_s3_bucket_policy" "saas_storage" {
  bucket = aws_s3_bucket.saas_storage.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEC2RoleAccess"
        Effect = "Allow"
        Principal = {
          AWS = var.ec2_iam_role_arn # IAM role ARN from IAM module
        }
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.saas_storage.arn,
          "${aws_s3_bucket.saas_storage.arn}/*"
        ]
      }
    ]
  })

  depends_on = [
    aws_s3_bucket_public_access_block.saas_storage
  ]
}

