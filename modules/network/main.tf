data "aws_region" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs       = var.availability_zones != null ? var.availability_zones : slice(data.aws_availability_zones.available.names, 0, var.az_count)
  az_count  = length(local.azs)
  nat_count = var.nat_gateway_strategy == "per_az" ? local.az_count : (var.nat_gateway_strategy == "single" ? 1 : 0)

  # Each tier receives a contiguous block of subnet numbers so the layout stays
  # readable as AZs or tiers are added: [public][private][data].
  public_subnet_cidrs = var.public_subnet_cidrs != null ? var.public_subnet_cidrs : [
    for i in range(local.az_count) : try(cidrsubnet(var.cidr_block, var.subnet_newbits, i), "0.0.0.0/32")
  ]

  private_subnet_cidrs = var.private_subnet_cidrs != null ? var.private_subnet_cidrs : [
    for i in range(local.az_count) : try(cidrsubnet(var.cidr_block, var.subnet_newbits, local.az_count + i), "0.0.0.0/32")
  ]

  data_subnet_cidrs = var.data_subnet_cidrs != null ? var.data_subnet_cidrs : [
    for i in range(local.az_count) : try(cidrsubnet(var.cidr_block, var.subnet_newbits, (2 * local.az_count) + i), "0.0.0.0/32")
  ]
}

# Fail at plan time with actionable messages instead of a provider error midway
# through apply.
resource "terraform_data" "validation" {
  input = var.name

  lifecycle {
    precondition {
      condition     = length(local.public_subnet_cidrs) == local.az_count && length(local.private_subnet_cidrs) == local.az_count && length(local.data_subnet_cidrs) == local.az_count
      error_message = "Each of public_subnet_cidrs, private_subnet_cidrs, and data_subnet_cidrs must contain exactly one CIDR per availability zone."
    }

    precondition {
      condition     = (var.public_subnet_cidrs != null && var.private_subnet_cidrs != null && var.data_subnet_cidrs != null) || can(cidrsubnet(var.cidr_block, var.subnet_newbits, (3 * local.az_count) - 1))
      error_message = "cidr_block is too small for subnet_newbits and az_count. Use a larger VPC CIDR, fewer AZs, or fewer subnet_newbits."
    }

    precondition {
      condition = alltrue([
        for cidr in concat(local.public_subnet_cidrs, local.private_subnet_cidrs, local.data_subnet_cidrs) :
        can(cidrnetmask(cidr)) ? (
          cidrhost(cidr, 0) == split("/", cidr)[0] &&
          tonumber(split("/", cidr)[1]) >= tonumber(split("/", var.cidr_block)[1]) &&
          tonumber(split("/", cidr)[1]) <= 28
        ) : false
      ])
      error_message = "Every subnet CIDR must be an IPv4 network CIDR inside cidr_block, with a prefix between the VPC prefix and /28."
    }
  }
}

resource "aws_vpc" "this" {
  cidr_block           = var.cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.tags, {
    Name = var.name
  })

  depends_on = [terraform_data.validation]
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-igw"
  })
}

resource "aws_eip" "nat" {
  count = local.nat_count

  domain = "vpc"

  tags = merge(var.tags, {
    Name = "${var.name}-nat-${local.azs[count.index]}"
  })

  depends_on = [aws_internet_gateway.this]
}

resource "aws_nat_gateway" "this" {
  count = local.nat_count

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(var.tags, {
    Name = "${var.name}-nat-${local.azs[count.index]}"
  })

  depends_on = [
    aws_internet_gateway.this,
    aws_route.public_internet,
  ]
}
