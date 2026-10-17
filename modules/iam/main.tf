# IAM Role for EC2 Instance
resource "aws_iam_role" "saas_ec2_role" {
  name = "${var.project}-${var.environment}-ec2-role-${var.aws_region}-01"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project}-${var.environment}-ec2-role-${var.aws_region}-01"
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

# IAM Policy for EC2 to access S3
resource "aws_iam_policy" "saas_ec2_s3_policy" {
  name        = "${var.project}-${var.environment}-ec2-s3-policy-${var.aws_region}-01"
  description = "Policy allowing EC2 instance to access S3 bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          var.s3_bucket_arn,
          "${var.s3_bucket_arn}/*"
        ]
      }
    ]
  })

  tags = {
    Name        = "${var.project}-${var.environment}-ec2-s3-policy-${var.aws_region}-01"
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

# Attach S3 policy to EC2 role
resource "aws_iam_role_policy_attachment" "saas_ec2_s3_attachment" {
  role       = aws_iam_role.saas_ec2_role.name
  policy_arn = aws_iam_policy.saas_ec2_s3_policy.arn
}

# Attach CloudWatch Logs policy for EC2 (for system logs)
resource "aws_iam_role_policy_attachment" "saas_ec2_cloudwatch_logs" {
  role       = aws_iam_role.saas_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Instance Profile for EC2
resource "aws_iam_instance_profile" "saas_ec2_profile" {
  name = "${var.project}-${var.environment}-ec2-profile-${var.aws_region}-01"
  role = aws_iam_role.saas_ec2_role.name

  tags = {
    Name        = "${var.project}-${var.environment}-ec2-profile-${var.aws_region}-01"
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

# IAM User for application access (least privileges)
resource "aws_iam_user" "saas_app_user" {
  name = "${var.project}-${var.environment}-app-user-${var.aws_region}-01"

  tags = {
    Name        = "${var.project}-${var.environment}-app-user-${var.aws_region}-01"
    Environment = var.environment
    Project     = var.project
    Purpose     = "Application user with limited S3 access"
    ManagedBy   = "Terraform"
  }
}

# IAM Policy for application user (S3 read/write only)
resource "aws_iam_policy" "saas_app_user_s3_policy" {
  name        = "${var.project}-${var.environment}-app-user-s3-policy-${var.aws_region}-01"
  description = "Policy allowing application user to access S3 bucket only"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          var.s3_bucket_arn,
          "${var.s3_bucket_arn}/*"
        ]
      }
    ]
  })

  tags = {
    Name        = "${var.project}-${var.environment}-app-user-s3-policy-${var.aws_region}-01"
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

# Attach S3 policy to application user
resource "aws_iam_user_policy_attachment" "saas_app_user_s3_attachment" {
  user       = aws_iam_user.saas_app_user.name
  policy_arn = aws_iam_policy.saas_app_user_s3_policy.arn
}

# IAM User for DevOps access (read-only access to resources)
resource "aws_iam_user" "saas_devops_user" {
  name = "${var.project}-${var.environment}-devops-user-${var.aws_region}-01"

  tags = {
    Name        = "${var.project}-${var.environment}-devops-user-${var.aws_region}-01"
    Environment = var.environment
    Project     = var.project
    Purpose     = "DevOps user with read-only access"
    ManagedBy   = "Terraform"
  }
}

# IAM Policy for DevOps user (read-only access)
resource "aws_iam_policy" "saas_devops_readonly_policy" {
  name        = "${var.project}-${var.environment}-devops-readonly-policy-${var.aws_region}-01"
  description = "Policy allowing DevOps user read-only access to resources"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:Describe*",
          "rds:Describe*",
          "rds:ListTagsForResource",
          "s3:GetObject",
          "s3:ListBucket",
          "cloudwatch:Describe*",
          "cloudwatch:Get*",
          "cloudwatch:List*",
          "logs:Describe*",
          "logs:Get*",
          "logs:FilterLogEvents"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "${var.project}-${var.environment}-devops-readonly-policy-${var.aws_region}-01"
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

# Attach read-only policy to DevOps user
resource "aws_iam_user_policy_attachment" "saas_devops_readonly_attachment" {
  user       = aws_iam_user.saas_devops_user.name
  policy_arn = aws_iam_policy.saas_devops_readonly_policy.arn
}

# Optional: Create access keys for application user (if needed)
resource "aws_iam_access_key" "saas_app_user_key" {
  count = var.create_app_user_access_key ? 1 : 0
  user  = aws_iam_user.saas_app_user.name
}

# Optional: Create access keys for DevOps user (if needed)
resource "aws_iam_access_key" "saas_devops_user_key" {
  count = var.create_devops_user_access_key ? 1 : 0
  user  = aws_iam_user.saas_devops_user.name
}

