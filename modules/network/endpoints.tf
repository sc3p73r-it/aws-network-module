resource "aws_vpc_endpoint" "gateway" {
  for_each = var.gateway_endpoint_services

  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.${each.value}"
  vpc_endpoint_type = "Gateway"

  # Both the application and data tiers can reach gateway endpoints without
  # leaving the VPC (and without a NAT gateway).
  route_table_ids = concat(aws_route_table.private[*].id, aws_route_table.data[*].id)

  tags = merge(var.tags, {
    Name = "${var.name}-${each.value}"
  })
}

resource "aws_vpc_endpoint" "interface" {
  for_each = var.interface_endpoint_services

  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.${each.value}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.endpoints[0].id]
  private_dns_enabled = var.interface_endpoint_private_dns

  tags = merge(var.tags, {
    Name = "${var.name}-${each.value}"
  })
}
