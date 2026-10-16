# Data source for availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# VPC
resource "aws_vpc" "saas_main_vpc" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.project}-${var.environment}-vpc-${var.aws_region}-01"
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

# Public Subnets (2)
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.saas_main_vpc.id
  cidr_block              = cidrsubnet(var.vpc_cidr_block, 4, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.project}-${var.environment}-public-subnet-${var.aws_region}-${format("%02d", count.index + 1)}"
    Environment = var.environment
    Project     = var.project
    Type        = "public"
    ManagedBy   = "Terraform"
  }
}

# Private Subnets (2)
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.saas_main_vpc.id
  cidr_block        = cidrsubnet(var.vpc_cidr_block, 4, count.index + 2)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name        = "${var.project}-${var.environment}-private-subnet-${var.aws_region}-${format("%02d", count.index + 1)}"
    Environment = var.environment
    Project     = var.project
    Type        = "private"
    ManagedBy   = "Terraform"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "saas_igw" {
  vpc_id = aws_vpc.saas_main_vpc.id

  tags = {
    Name        = "${var.project}-${var.environment}-igw-${var.aws_region}-01"
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

# Number of NAT Gateways: one per AZ when nat_per_az = true (HA), otherwise a single
# shared NAT Gateway (cost savings, the staging/dev default).
locals {
  nat_gateway_count = var.nat_per_az ? length(aws_subnet.public) : 1
}

# Elastic IP(s) for NAT Gateway(s)
resource "aws_eip" "nat_eip" {
  count      = local.nat_gateway_count
  domain     = "vpc"
  depends_on = [aws_internet_gateway.saas_igw]

  tags = {
    Name        = "${var.project}-${var.environment}-nat-eip-${var.aws_region}-${format("%02d", count.index + 1)}"
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

# Preserve existing single-NAT state (staging) when converting to a counted resource.
moved {
  from = aws_eip.nat_eip
  to   = aws_eip.nat_eip[0]
}

# NAT Gateway(s) - single shared by default, one per AZ when nat_per_az = true
resource "aws_nat_gateway" "saas_nat" {
  count         = local.nat_gateway_count
  allocation_id = aws_eip.nat_eip[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name        = "${var.project}-${var.environment}-nat-${var.aws_region}-${format("%02d", count.index + 1)}"
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }

  depends_on = [aws_internet_gateway.saas_igw]
}

moved {
  from = aws_nat_gateway.saas_nat
  to   = aws_nat_gateway.saas_nat[0]
}

# Route Table for Public Subnets
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.saas_main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.saas_igw.id
  }

  tags = {
    Name        = "${var.project}-${var.environment}-public-rt-${var.aws_region}-01"
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

# Route Table(s) for Private Subnets - one per NAT Gateway
resource "aws_route_table" "private_rt" {
  count  = local.nat_gateway_count
  vpc_id = aws_vpc.saas_main_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.saas_nat[count.index].id
  }

  tags = {
    Name        = "${var.project}-${var.environment}-private-rt-${var.aws_region}-${format("%02d", count.index + 1)}"
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

moved {
  from = aws_route_table.private_rt
  to   = aws_route_table.private_rt[0]
}

# Route Table Association for Public Subnets
resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public_rt.id
}

# Route Table Association for Private Subnets
# With a single NAT all private subnets share private_rt[0]; with per-AZ NAT each
# private subnet uses the route table for its own AZ.
resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = var.nat_per_az ? aws_route_table.private_rt[count.index].id : aws_route_table.private_rt[0].id
}

# Security Group for EC2 (saas-stg-sg)
resource "aws_security_group" "saas_ec2_sg" {
  count       = var.create_default_security_groups ? 1 : 0
  name        = "${var.project}-${var.environment}-sg"
  description = "Security group for SaaS EC2 instance allowing HTTP, HTTPS, port 3000, SSH, and RDS PostgreSQL"
  vpc_id      = aws_vpc.saas_main_vpc.id

  # HTTP
  ingress {
    description = "HTTP - Web traffic"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS
  ingress {
    description = "HTTPS - Web traffic"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Port 3000 - Application
  ingress {
    description = "Application port 3000"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH - Configurable CIDR blocks (should be restricted for production)
  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidr_blocks
  }

  # Note: EC2 doesn't need ingress rule for PostgreSQL - it initiates outbound connections to RDS
  # The RDS security group allows inbound PostgreSQL from EC2 security group

  # Allow all outbound traffic
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project}-${var.environment}-sg"
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

moved {
  from = aws_security_group.saas_ec2_sg
  to   = aws_security_group.saas_ec2_sg[0]
}

# Security Group for RDS PostgreSQL
resource "aws_security_group" "saas_rds_sg" {
  count       = var.create_default_security_groups ? 1 : 0
  name        = "${var.project}-${var.environment}-rds-sg"
  description = "Security group for SaaS RDS PostgreSQL database"
  vpc_id      = aws_vpc.saas_main_vpc.id

  # PostgreSQL - Only allow from EC2 security group
  ingress {
    description     = "PostgreSQL from EC2 instance"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.saas_ec2_sg[0].id]
  }

  # Allow all outbound traffic
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

moved {
  from = aws_security_group.saas_rds_sg
  to   = aws_security_group.saas_rds_sg[0]
}

