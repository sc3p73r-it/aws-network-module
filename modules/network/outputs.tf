output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.this.id
}

output "vpc_arn" {
  description = "ARN of the VPC."
  value       = aws_vpc.this.arn
}

output "vpc_cidr_block" {
  description = "IPv4 CIDR block of the VPC."
  value       = aws_vpc.this.cidr_block
}

output "region" {
  description = "AWS region the module was deployed into."
  value       = data.aws_region.current.name
}

output "availability_zones" {
  description = "Availability zones used by the subnets."
  value       = local.azs
}

output "subnet_ids" {
  description = "Subnet IDs grouped by tier. Each list is ordered by availability zone."
  value = {
    public  = aws_subnet.public[*].id
    private = aws_subnet.private[*].id
    data    = aws_subnet.data[*].id
  }
}

output "subnet_cidr_blocks" {
  description = "Subnet CIDR blocks grouped by tier. Each list is ordered by availability zone."
  value = {
    public  = local.public_subnet_cidrs
    private = local.private_subnet_cidrs
    data    = local.data_subnet_cidrs
  }
}

output "internet_gateway_id" {
  description = "ID of the internet gateway."
  value       = aws_internet_gateway.this.id
}

output "nat_gateway_ids" {
  description = "NAT gateway IDs. One per AZ for per_az, one total for single, empty for none."
  value       = aws_nat_gateway.this[*].id
}

output "nat_gateway_public_ips" {
  description = "Elastic IP addresses attached to the NAT gateways."
  value       = aws_eip.nat[*].public_ip
}

output "route_table_ids" {
  description = "Route table IDs by tier. Private route tables are ordered by availability zone."
  value = {
    public  = aws_route_table.public.id
    private = aws_route_table.private[*].id
    data    = aws_route_table.data.id
  }
}

output "security_group_ids" {
  description = "Security group IDs for each tier. endpoints is null when no interface endpoints are enabled."
  value = {
    web       = aws_security_group.web.id
    app       = aws_security_group.app.id
    data      = aws_security_group.data.id
    endpoints = one(aws_security_group.endpoints[*].id)
  }
}

output "network_acl_ids" {
  description = "Network ACL IDs by tier. Null when create_network_acls is false."
  value = {
    public  = one(aws_network_acl.public[*].id)
    private = one(aws_network_acl.private[*].id)
    data    = one(aws_network_acl.data[*].id)
  }
}

output "vpc_endpoint_ids" {
  description = "VPC endpoint IDs keyed by endpoint type and service."
  value = merge(
    { for service, endpoint in aws_vpc_endpoint.gateway : "gateway-${service}" => endpoint.id },
    { for service, endpoint in aws_vpc_endpoint.interface : "interface-${service}" => endpoint.id }
  )
}

output "flow_log_id" {
  description = "ID of the VPC flow log, or null when flow logs are disabled."
  value       = one(aws_flow_log.this[*].id)
}
