# Network Module Outputs

# VPC Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.saas_main_vpc.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.saas_main_vpc.cidr_block
}

output "vpc_arn" {
  description = "ARN of the VPC"
  value       = aws_vpc.saas_main_vpc.arn
}

# Subnet Outputs
output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = aws_subnet.private[*].id
}

output "public_subnet_cidr_blocks" {
  description = "CIDR blocks of the public subnets"
  value       = aws_subnet.public[*].cidr_block
}

output "private_subnet_cidr_blocks" {
  description = "CIDR blocks of the private subnets"
  value       = aws_subnet.private[*].cidr_block
}

# Gateway Outputs
output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.saas_igw.id
}

output "nat_gateway_ids" {
  description = "IDs of the NAT Gateway(s)"
  value       = aws_nat_gateway.saas_nat[*].id
}

output "nat_gateway_public_ips" {
  description = "Public IP(s) of the NAT Gateway(s)"
  value       = aws_eip.nat_eip[*].public_ip
}

# Route Table Outputs
output "public_route_table_id" {
  description = "ID of the public route table"
  value       = aws_route_table.public_rt.id
}

output "private_route_table_ids" {
  description = "IDs of the private route table(s)"
  value       = aws_route_table.private_rt[*].id
}

# Security Group Outputs (null when create_default_security_groups = false)
output "ec2_security_group_id" {
  description = "ID of the EC2 security group"
  value       = try(aws_security_group.saas_ec2_sg[0].id, null)
}

output "rds_security_group_id" {
  description = "ID of the RDS security group"
  value       = try(aws_security_group.saas_rds_sg[0].id, null)
}

# Availability Zones Output
output "availability_zones" {
  description = "List of availability zones used"
  value       = data.aws_availability_zones.available.names
}

# Network Summary Output
output "network_summary" {
  description = "Summary of the network infrastructure"
  value = {
    vpc_id             = aws_vpc.saas_main_vpc.id
    vpc_cidr           = aws_vpc.saas_main_vpc.cidr_block
    public_subnets     = aws_subnet.public[*].id
    private_subnets    = aws_subnet.private[*].id
    internet_gateway   = aws_internet_gateway.saas_igw.id
    nat_gateways       = aws_nat_gateway.saas_nat[*].id
    nat_gateway_ips    = aws_eip.nat_eip[*].public_ip
    ec2_security_group = try(aws_security_group.saas_ec2_sg[0].id, null)
    rds_security_group = try(aws_security_group.saas_rds_sg[0].id, null)
  }
}

