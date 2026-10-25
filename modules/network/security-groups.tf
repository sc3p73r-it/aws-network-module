locals {
  web_ingress_rules = {
    for pair in setproduct(toset(var.web_ingress_ports), toset(var.web_ingress_cidr_blocks)) :
    "tcp-${pair[0]}-${replace(pair[1], "/", "_")}" => {
      port = pair[0]
      cidr = pair[1]
    }
  }

  web_to_app_rules = {
    for port in toset(var.app_ingress_ports) : "tcp-${port}" => port
  }

  app_https_egress_rules = {
    for cidr in toset(var.app_egress_cidr_blocks) : replace(cidr, "/", "_") => cidr
  }

  data_https_egress_rules = {
    for cidr in toset(var.data_egress_cidr_blocks) : replace(cidr, "/", "_") => cidr
  }

  app_to_data_rules = {
    for port in toset(var.data_ingress_ports) : "tcp-${port}" => port
  }
}

# The default security group is unused by this module; strip its permissive
# rules so accidental attachments fail closed.
resource "aws_default_security_group" "this" {
  count = var.manage_default_security_group ? 1 : 0

  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-default"
  })
}

# Public / load balancer tier
resource "aws_security_group" "web" {
  name        = "${var.name}-web"
  description = "Public web and load balancer tier"
  vpc_id      = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-web"
    Tier = "public"
  })
}

resource "aws_vpc_security_group_ingress_rule" "web" {
  for_each = local.web_ingress_rules

  security_group_id = aws_security_group.web.id
  description       = "TCP ${each.value.port} from ${each.value.cidr}"
  cidr_ipv4         = each.value.cidr
  ip_protocol       = "tcp"
  from_port         = each.value.port
  to_port           = each.value.port
}

resource "aws_vpc_security_group_egress_rule" "web_to_app" {
  for_each = local.web_to_app_rules

  security_group_id            = aws_security_group.web.id
  description                  = "Forward traffic to the application tier on TCP ${each.value}"
  referenced_security_group_id = aws_security_group.app.id
  ip_protocol                  = "tcp"
  from_port                    = each.value
  to_port                      = each.value
}

# Link-local services every EC2 instance needs: IMDS and the Amazon Time Sync
# service. These stay reachable even when application egress is restricted.
resource "aws_vpc_security_group_egress_rule" "web_imds" {
  security_group_id = aws_security_group.web.id
  description       = "Instance metadata service"
  cidr_ipv4         = "169.254.169.254/32"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "web_ntp" {
  security_group_id = aws_security_group.web.id
  description       = "Amazon Time Sync service"
  cidr_ipv4         = "169.254.169.123/32"
  ip_protocol       = "udp"
  from_port         = 123
  to_port           = 123
}

# Private / application tier
resource "aws_security_group" "app" {
  name        = "${var.name}-app"
  description = "Private application tier"
  vpc_id      = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-app"
    Tier = "private"
  })
}

resource "aws_vpc_security_group_ingress_rule" "app_from_web" {
  for_each = local.web_to_app_rules

  security_group_id            = aws_security_group.app.id
  description                  = "Application port TCP ${each.value} from the web tier"
  referenced_security_group_id = aws_security_group.web.id
  ip_protocol                  = "tcp"
  from_port                    = each.value
  to_port                      = each.value
}

resource "aws_vpc_security_group_egress_rule" "app_to_data" {
  for_each = local.app_to_data_rules

  security_group_id            = aws_security_group.app.id
  description                  = "Data port TCP ${each.value} to the data tier"
  referenced_security_group_id = aws_security_group.data.id
  ip_protocol                  = "tcp"
  from_port                    = each.value
  to_port                      = each.value
}

resource "aws_vpc_security_group_egress_rule" "app_https" {
  for_each = local.app_https_egress_rules

  security_group_id = aws_security_group.app.id
  description       = "HTTPS egress to ${each.value}"
  cidr_ipv4         = each.value
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

# Always permit HTTPS to in-VPC endpoints (interface endpoint ENIs and the
# Route 53 resolver live inside the VPC CIDR).
resource "aws_vpc_security_group_egress_rule" "app_https_vpc" {
  security_group_id = aws_security_group.app.id
  description       = "HTTPS to VPC endpoints"
  cidr_ipv4         = var.cidr_block
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

resource "aws_vpc_security_group_egress_rule" "app_dns_udp" {
  security_group_id = aws_security_group.app.id
  description       = "DNS to the Route 53 resolver"
  cidr_ipv4         = var.cidr_block
  ip_protocol       = "udp"
  from_port         = 53
  to_port           = 53
}

resource "aws_vpc_security_group_egress_rule" "app_dns_tcp" {
  security_group_id = aws_security_group.app.id
  description       = "DNS over TCP to the Route 53 resolver"
  cidr_ipv4         = var.cidr_block
  ip_protocol       = "tcp"
  from_port         = 53
  to_port           = 53
}

resource "aws_vpc_security_group_egress_rule" "app_imds" {
  security_group_id = aws_security_group.app.id
  description       = "Instance metadata service"
  cidr_ipv4         = "169.254.169.254/32"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "app_ntp" {
  security_group_id = aws_security_group.app.id
  description       = "Amazon Time Sync service"
  cidr_ipv4         = "169.254.169.123/32"
  ip_protocol       = "udp"
  from_port         = 123
  to_port           = 123
}

# ECS tasks reach the task metadata endpoint through a link-local address.
resource "aws_vpc_security_group_egress_rule" "app_ecs_metadata" {
  security_group_id = aws_security_group.app.id
  description       = "ECS task metadata endpoint"
  cidr_ipv4         = "169.254.170.2/32"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}

# Isolated data tier
resource "aws_security_group" "data" {
  name        = "${var.name}-data"
  description = "Isolated data tier"
  vpc_id      = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-data"
    Tier = "data"
  })
}

resource "aws_vpc_security_group_ingress_rule" "data_from_app" {
  for_each = local.app_to_data_rules

  security_group_id            = aws_security_group.data.id
  description                  = "Data port TCP ${each.value} from the application tier"
  referenced_security_group_id = aws_security_group.app.id
  ip_protocol                  = "tcp"
  from_port                    = each.value
  to_port                      = each.value
}

resource "aws_vpc_security_group_egress_rule" "data_https" {
  for_each = local.data_https_egress_rules

  security_group_id = aws_security_group.data.id
  description       = "HTTPS egress to ${each.value}"
  cidr_ipv4         = each.value
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

resource "aws_vpc_security_group_egress_rule" "data_https_vpc" {
  security_group_id = aws_security_group.data.id
  description       = "HTTPS to VPC endpoints"
  cidr_ipv4         = var.cidr_block
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

resource "aws_vpc_security_group_egress_rule" "data_dns_udp" {
  security_group_id = aws_security_group.data.id
  description       = "DNS to the Route 53 resolver"
  cidr_ipv4         = var.cidr_block
  ip_protocol       = "udp"
  from_port         = 53
  to_port           = 53
}

resource "aws_vpc_security_group_egress_rule" "data_dns_tcp" {
  security_group_id = aws_security_group.data.id
  description       = "DNS over TCP to the Route 53 resolver"
  cidr_ipv4         = var.cidr_block
  ip_protocol       = "tcp"
  from_port         = 53
  to_port           = 53
}

resource "aws_vpc_security_group_egress_rule" "data_imds" {
  security_group_id = aws_security_group.data.id
  description       = "Instance metadata service"
  cidr_ipv4         = "169.254.169.254/32"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "data_ntp" {
  security_group_id = aws_security_group.data.id
  description       = "Amazon Time Sync service"
  cidr_ipv4         = "169.254.169.123/32"
  ip_protocol       = "udp"
  from_port         = 123
  to_port           = 123
}

# Shared by all interface VPC endpoints
resource "aws_security_group" "endpoints" {
  count = length(var.interface_endpoint_services) > 0 ? 1 : 0

  name        = "${var.name}-endpoints"
  description = "Interface VPC endpoints"
  vpc_id      = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-endpoints"
  })
}

resource "aws_vpc_security_group_ingress_rule" "endpoints_https" {
  count = length(var.interface_endpoint_services) > 0 ? 1 : 0

  security_group_id = aws_security_group.endpoints[0].id
  description       = "HTTPS from inside the VPC"
  cidr_ipv4         = var.cidr_block
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}
