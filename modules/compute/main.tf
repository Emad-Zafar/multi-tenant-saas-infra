# Data source for latest Ubuntu 22.04 LTS AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Data source for existing Key Pair (key pair already exists in AWS)
data "aws_key_pair" "saas_server_keypair" {
  key_name = var.key_pair_name
}

# Elastic IP for EC2 instance
resource "aws_eip" "saas_ec2_eip" {
  domain = "vpc"

  tags = {
    Name        = "${var.project}-${var.environment}-ec2-eip-${var.aws_region}-01"
    Environment = var.environment
    Project     = var.project
    Purpose     = "EC2 instance public IP"
    ManagedBy   = "Terraform"
  }
}

# EC2 Instance
resource "aws_instance" "saas_server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = data.aws_key_pair.saas_server_keypair.key_name
  subnet_id              = var.public_subnet_ids[0] # First public subnet
  vpc_security_group_ids = [var.ec2_security_group_id]
  iam_instance_profile   = var.iam_instance_profile_name != "" ? var.iam_instance_profile_name : null

  # Root volume configuration
  root_block_device {
    volume_size = var.root_volume_size
    volume_type = var.root_volume_type
    encrypted   = var.root_volume_encrypted

    tags = {
      Name        = "${var.project}-${var.environment}-ec2-root-${var.aws_region}-01"
      Environment = var.environment
      Project     = var.project
      VolumeType  = var.root_volume_type
      Encrypted   = tostring(var.root_volume_encrypted)
      ManagedBy   = "Terraform"
    }
  }

  # User data for initial setup
  user_data = <<-EOF
              #!/bin/bash
              
              # Update system packages
              sudo apt update -y
              sudo apt upgrade -y
              
              # Install AWS CLI v2
              curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
              unzip -q awscliv2.zip
              sudo ./aws/install
              rm -rf aws awscliv2.zip
              
              # Install additional tools
              sudo apt install -y git curl wget unzip
              
              # Create application directories
              sudo mkdir -p /opt/saas/{app,logs,data}
              sudo chown -R ubuntu:ubuntu /opt/saas
              
              # Set up basic firewall rules
              sudo ufw allow 22/tcp
              sudo ufw allow 80/tcp
              sudo ufw allow 443/tcp
              sudo ufw allow 3000/tcp
              sudo ufw --force enable
              
              # Log the setup completion
              echo "SaaS server setup completed at $(date)" > /var/log/saas-setup.log
              echo "Ubuntu 22.04 LTS with AWS CLI v2 installed" >> /var/log/saas-setup.log
              EOF

  tags = {
    Name         = "${var.project}-${var.environment}-ec2-${var.aws_region}-01"
    Environment  = var.environment
    Project      = var.project
    Purpose      = "SaaS Application Server"
    OS           = "Ubuntu 22.04 LTS"
    InstanceType = var.instance_type
    ManagedBy    = "Terraform"
  }
}

# Associate Elastic IP with EC2 instance
resource "aws_eip_association" "saas_ec2_eip_assoc" {
  instance_id   = aws_instance.saas_server.id
  allocation_id = aws_eip.saas_ec2_eip.id
}

