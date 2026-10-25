output "vpc_id" {
  description = "ID of the created VPC."
  value       = module.network.vpc_id
}

output "availability_zones" {
  description = "Availability zones used by the network."
  value       = module.network.availability_zones
}

output "subnet_ids" {
  description = "Subnet IDs grouped by tier."
  value       = module.network.subnet_ids
}

output "security_group_ids" {
  description = "Security group IDs grouped by tier."
  value       = module.network.security_group_ids
}

output "nat_gateway_public_ips" {
  description = "Public IPs of the NAT gateways."
  value       = module.network.nat_gateway_public_ips
}
