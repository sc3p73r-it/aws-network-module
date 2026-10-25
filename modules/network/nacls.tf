locals {
  public_nacl_web_ingress = flatten([
    for port_index, port in var.web_ingress_ports : [
      for cidr_index, cidr in var.web_ingress_cidr_blocks : {
        rule_number = 100 + (port_index * length(var.web_ingress_cidr_blocks)) + cidr_index
        protocol   = "tcp"
        from_port  = port
        to_port    = port
        cidr_block = cidr
      }
    ]
  ])

  public_nacl_ephemeral_rule_number = 100 + length(local.public_nacl_web_ingress)
  public_nacl_vpc_rule_number       = local.public_nacl_ephemeral_rule_number + 1

  public_nacl_ingress = concat(
    local.public_nacl_web_ingress,
    [
      {
        rule_number = local.public_nacl_ephemeral_rule_number
        protocol   = "tcp"
        from_port  = 1024
        to_port    = 65535
        cidr_block = "0.0.0.0/0"
      },
      {
        rule_number = local.public_nacl_vpc_rule_number
        protocol   = "-1"
        from_port  = 0
        to_port    = 0
        cidr_block = var.cidr_block
      },
    ]
  )

  public_nacl_egress = [
    {
      rule_number = 100
      protocol   = "-1"
      from_port  = 0
      to_port    = 0
      cidr_block = "0.0.0.0/0"
    },
  ]

  private_nacl_ingress = [
    {
      rule_number = 100
      protocol   = "-1"
      from_port  = 0
      to_port    = 0
      cidr_block = var.cidr_block
    },
    {
      rule_number = 110
      protocol   = "tcp"
      from_port  = 1024
      to_port    = 65535
      cidr_block = "0.0.0.0/0"
    },
  ]

  private_nacl_egress = [
    {
      rule_number = 100
      protocol   = "-1"
      from_port  = 0
      to_port    = 0
      cidr_block = "0.0.0.0/0"
    },
  ]

  data_nacl_ingress = [
    {
      rule_number = 100
      protocol   = "-1"
      from_port  = 0
      to_port    = 0
      cidr_block = var.cidr_block
    },
    {
      rule_number = 110
      protocol   = "tcp"
      from_port  = 1024
      to_port    = 65535
      cidr_block = "0.0.0.0/0"
    },
  ]

  data_nacl_egress = [
    {
      rule_number = 100
      protocol   = "-1"
      from_port  = 0
      to_port    = 0
      cidr_block = var.cidr_block
    },
    {
      rule_number = 110
      protocol   = "tcp"
      from_port  = 443
      to_port    = 443
      cidr_block = "0.0.0.0/0"
    },
    {
      rule_number = 120
      protocol   = "tcp"
      from_port  = 80
      to_port    = 80
      cidr_block = "169.254.169.254/32"
    },
    {
      rule_number = 130
      protocol   = "udp"
      from_port  = 123
      to_port    = 123
      cidr_block = "169.254.169.123/32"
    },
  ]
}

resource "aws_network_acl" "public" {
  count = var.create_network_acls ? 1 : 0

  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-public"
    Tier = "public"
  })

  dynamic "ingress" {
    for_each = local.public_nacl_ingress

    content {
      rule_no    = ingress.value.rule_number
      action     = "allow"
      protocol   = ingress.value.protocol
      from_port  = ingress.value.from_port
      to_port    = ingress.value.to_port
      cidr_block = ingress.value.cidr_block
    }
  }

  dynamic "egress" {
    for_each = local.public_nacl_egress

    content {
      rule_no    = egress.value.rule_number
      action     = "allow"
      protocol   = egress.value.protocol
      from_port  = egress.value.from_port
      to_port    = egress.value.to_port
      cidr_block = egress.value.cidr_block
    }
  }
}

resource "aws_network_acl" "private" {
  count = var.create_network_acls ? 1 : 0

  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-private"
    Tier = "private"
  })

  dynamic "ingress" {
    for_each = local.private_nacl_ingress

    content {
      rule_no    = ingress.value.rule_number
      action     = "allow"
      protocol   = ingress.value.protocol
      from_port  = ingress.value.from_port
      to_port    = ingress.value.to_port
      cidr_block = ingress.value.cidr_block
    }
  }

  dynamic "egress" {
    for_each = local.private_nacl_egress

    content {
      rule_no    = egress.value.rule_number
      action     = "allow"
      protocol   = egress.value.protocol
      from_port  = egress.value.from_port
      to_port    = egress.value.to_port
      cidr_block = egress.value.cidr_block
    }
  }
}

resource "aws_network_acl" "data" {
  count = var.create_network_acls ? 1 : 0

  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-data"
    Tier = "data"
  })

  dynamic "ingress" {
    for_each = local.data_nacl_ingress

    content {
      rule_no    = ingress.value.rule_number
      action     = "allow"
      protocol   = ingress.value.protocol
      from_port  = ingress.value.from_port
      to_port    = ingress.value.to_port
      cidr_block = ingress.value.cidr_block
    }
  }

  dynamic "egress" {
    for_each = local.data_nacl_egress

    content {
      rule_no    = egress.value.rule_number
      action     = "allow"
      protocol   = egress.value.protocol
      from_port  = egress.value.from_port
      to_port    = egress.value.to_port
      cidr_block = egress.value.cidr_block
    }
  }
}

resource "aws_network_acl_association" "public" {
  count = var.create_network_acls ? local.az_count : 0

  subnet_id      = aws_subnet.public[count.index].id
  network_acl_id = aws_network_acl.public[0].id
}

resource "aws_network_acl_association" "private" {
  count = var.create_network_acls ? local.az_count : 0

  subnet_id      = aws_subnet.private[count.index].id
  network_acl_id = aws_network_acl.private[0].id
}

resource "aws_network_acl_association" "data" {
  count = var.create_network_acls ? local.az_count : 0

  subnet_id      = aws_subnet.data[count.index].id
  network_acl_id = aws_network_acl.data[0].id
}
