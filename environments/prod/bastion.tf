# TEMPORARY SSM bastion for one-time DB bootstrap.
# All resources are gated by var.create_bastion. To remove: set create_bastion = false
# and apply (everything here is destroyed). No inbound SSH - access is via SSM only.

# Latest Amazon Linux 2023 AMI via the public SSM parameter.
data "aws_ssm_parameter" "al2023" {
  count = var.create_bastion ? 1 : 0
  name  = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

data "aws_iam_policy_document" "bastion_assume" {
  count = var.create_bastion ? 1 : 0
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "bastion" {
  count              = var.create_bastion ? 1 : 0
  name               = "${var.project}-${var.environment}-bastion-role-${var.aws_region}-01"
  assume_role_policy = data.aws_iam_policy_document.bastion_assume[0].json

  tags = {
    Name        = "${var.project}-${var.environment}-bastion-role-${var.aws_region}-01"
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

# SSM-only access (no SSH).
resource "aws_iam_role_policy_attachment" "bastion_ssm" {
  count      = var.create_bastion ? 1 : 0
  role       = aws_iam_role.bastion[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "bastion" {
  count = var.create_bastion ? 1 : 0
  name  = "${var.project}-${var.environment}-bastion-profile-${var.aws_region}-01"
  role  = aws_iam_role.bastion[0].name

  tags = {
    Name        = "${var.project}-${var.environment}-bastion-profile-${var.aws_region}-01"
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

resource "aws_instance" "bastion" {
  count                       = var.create_bastion ? 1 : 0
  ami                         = data.aws_ssm_parameter.al2023[0].value
  instance_type               = "t3.micro"
  subnet_id                   = module.network.private_subnet_ids[0]
  associate_public_ip_address = false
  iam_instance_profile        = aws_iam_instance_profile.bastion[0].name

  # Reuse the existing ECS security group (it can already reach RDS:5432) - no new rules.
  vpc_security_group_ids = [module.security_groups.ecs_security_group_id]

  tags = {
    Name        = "${var.project}-${var.environment}-bastion-${var.aws_region}-01"
    Environment = var.environment
    Project     = var.project
    Purpose     = "Temporary SSM bastion for one-time DB bootstrap"
    ManagedBy   = "Terraform"
  }

  # Ignore "latest AL2023" SSM-parameter AMI drift so routine AMI updates don't force
  # a replace of this temporary instance.
  lifecycle {
    ignore_changes = [ami]
  }
}

output "bastion_instance_id" {
  description = "Instance ID of the temporary SSM bastion (null when create_bastion = false)"
  value       = try(aws_instance.bastion[0].id, null)
}
