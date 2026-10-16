# VPC Endpoints module outputs

output "endpoints_security_group_id" {
  description = "ID of the interface-endpoint security group (null if no interface endpoints created)"
  value       = try(aws_security_group.endpoints[0].id, null)
}

output "interface_endpoint_ids" {
  description = "Map of logical name -> interface VPC endpoint ID"
  value       = { for name, ep in aws_vpc_endpoint.interface : name => ep.id }
}

output "s3_gateway_endpoint_id" {
  description = "ID of the S3 gateway endpoint (null if not created)"
  value       = try(aws_vpc_endpoint.s3[0].id, null)
}
