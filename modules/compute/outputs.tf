# Compute Module Outputs

output "ec2_instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.saas_server.id
}

output "ec2_instance_arn" {
  description = "ARN of the EC2 instance"
  value       = aws_instance.saas_server.arn
}

output "ec2_instance_private_ip" {
  description = "Private IP of the EC2 instance"
  value       = aws_instance.saas_server.private_ip
}

output "ec2_instance_public_ip" {
  description = "Public IP of the EC2 instance (Elastic IP)"
  value       = aws_eip.saas_ec2_eip.public_ip
}

output "ec2_elastic_ip_id" {
  description = "ID of the Elastic IP"
  value       = aws_eip.saas_ec2_eip.id
}

output "ec2_elastic_ip_allocation_id" {
  description = "Allocation ID of the Elastic IP"
  value       = aws_eip.saas_ec2_eip.allocation_id
}

output "key_pair_name" {
  description = "Name of the key pair"
  value       = data.aws_key_pair.saas_server_keypair.key_name
}

output "key_pair_id" {
  description = "ID of the key pair"
  value       = data.aws_key_pair.saas_server_keypair.id
}

output "ssh_command" {
  description = "SSH command to connect to the EC2 instance"
  value       = "ssh -i <path-to-key> ubuntu@${aws_eip.saas_ec2_eip.public_ip}"
}

