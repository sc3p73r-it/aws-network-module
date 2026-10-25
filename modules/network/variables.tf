variable "name" {
  description = "Name prefix for the VPC and all resources created by this module."
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9-]{0,39}$", var.name))
    error_message = "name must be 1-40 characters, start with a letter or digit, and contain only letters, digits, and hyphens."
  }
}

variable "cidr_block" {
  description = "IPv4 CIDR block for the VPC. A /16 is recommended so all three tiers fit comfortably."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.cidr_block)) ? (cidrhost(var.cidr_block, 0) == split("/", var.cidr_block)[0] && tonumber(split("/", var.cidr_block)[1]) >= 16 && tonumber(split("/", var.cidr_block)[1]) <= 28) : false
    error_message = "cidr_block must be an IPv4 network CIDR between /16 and /28 with no host bits set, for example 10.0.0.0/16."
  }
}

variable "az_count" {
  description = "Number of availability zones to spread subnets across. Ignored when availability_zones is set."
  type        = number
  default     = 3

  validation {
    condition     = var.az_count >= 1 && var.az_count <= 5 && floor(var.az_count) == var.az_count
    error_message = "az_count must be a whole number between 1 and 5."
  }
}

variable "availability_zones" {
  description = "Optional explicit list of availability zone names to use. When set, az_count is derived from this list."
  type        = list(string)
  default     = null

  validation {
    condition     = var.availability_zones == null ? true : (length(var.availability_zones) >= 1 && length(var.availability_zones) <= 5 && length(distinct(var.availability_zones)) == length(var.availability_zones))
    error_message = "availability_zones must contain between 1 and 5 distinct availability zone names, or be null."
  }
}

variable "subnet_newbits" {
  description = "Additional bits used to carve subnet CIDRs out of cidr_block when explicit CIDR lists are not supplied. 4 yields /20 subnets in a /16 VPC."
  type        = number
  default     = 4

  validation {
    condition     = var.subnet_newbits >= 2 && var.subnet_newbits <= 8 && floor(var.subnet_newbits) == var.subnet_newbits
    error_message = "subnet_newbits must be a whole number between 2 and 8."
  }
}

variable "public_subnet_cidrs" {
  description = "Optional explicit CIDR list for the public tier. Must contain one CIDR per availability zone."
  type        = list(string)
  default     = null
}

variable "private_subnet_cidrs" {
  description = "Optional explicit CIDR list for the private (application) tier. Must contain one CIDR per availability zone."
  type        = list(string)
  default     = null
}

variable "data_subnet_cidrs" {
  description = "Optional explicit CIDR list for the isolated data tier. Must contain one CIDR per availability zone."
  type        = list(string)
  default     = null
}

variable "map_public_ip_on_launch" {
  description = "Automatically assign public IPs to instances launched in public subnets. Best practice is false; use load balancers and NAT gateways instead."
  type        = bool
  default     = false
}

variable "nat_gateway_strategy" {
  description = "NAT strategy for private subnets: per_az (one NAT per AZ, highly available), single (one shared NAT, cheaper), or none (no internet egress)."
  type        = string
  default     = "per_az"

  validation {
    condition     = contains(["per_az", "single", "none"], var.nat_gateway_strategy)
    error_message = "nat_gateway_strategy must be one of: per_az, single, none."
  }
}

variable "create_network_acls" {
  description = "Create baseline network ACLs for each tier. Security groups remain the primary control; ACLs provide a stateless subnet-level backstop."
  type        = bool
  default     = true
}

variable "manage_default_security_group" {
  description = "Remove all rules from the VPC default security group. Leave false if any workload relies on it."
  type        = bool
  default     = true
}

variable "web_ingress_cidr_blocks" {
  description = "IPv4 CIDRs allowed to reach the web/load-balancer tier on web_ingress_ports."
  type        = list(string)
  default     = ["0.0.0.0/0"]

  validation {
    condition     = alltrue([for cidr in var.web_ingress_cidr_blocks : can(cidrnetmask(cidr))])
    error_message = "Every entry in web_ingress_cidr_blocks must be a valid IPv4 CIDR block."
  }
}

variable "web_ingress_ports" {
  description = "TCP ports exposed on the web/load-balancer tier."
  type        = list(number)
  default     = [80, 443]

  validation {
    condition     = alltrue([for port in var.web_ingress_ports : port > 0 && port <= 65535])
    error_message = "Every entry in web_ingress_ports must be a TCP port between 1 and 65535."
  }
}

variable "app_ingress_ports" {
  description = "TCP ports the web tier may use to reach the application tier."
  type        = list(number)
  default     = [8080]

  validation {
    condition     = alltrue([for port in var.app_ingress_ports : port > 0 && port <= 65535])
    error_message = "Every entry in app_ingress_ports must be a TCP port between 1 and 65535."
  }
}

variable "data_ingress_ports" {
  description = "TCP ports the application tier may use to reach the data tier, for example 5432 for PostgreSQL."
  type        = list(number)
  default     = [5432]

  validation {
    condition     = alltrue([for port in var.data_ingress_ports : port > 0 && port <= 65535])
    error_message = "Every entry in data_ingress_ports must be a TCP port between 1 and 65535."
  }
}

variable "app_egress_cidr_blocks" {
  description = "IPv4 CIDRs the application tier may reach on TCP/443 (for example through NAT). Set to [] to allow only in-VPC HTTPS via VPC endpoints."
  type        = list(string)
  default     = ["0.0.0.0/0"]

  validation {
    condition     = alltrue([for cidr in var.app_egress_cidr_blocks : can(cidrnetmask(cidr))])
    error_message = "Every entry in app_egress_cidr_blocks must be a valid IPv4 CIDR block."
  }
}

variable "data_egress_cidr_blocks" {
  description = "IPv4 CIDRs the data tier may reach on TCP/443. The data subnets have no NAT route, so this mainly enables S3 and DynamoDB gateway endpoints."
  type        = list(string)
  default     = ["0.0.0.0/0"]

  validation {
    condition     = alltrue([for cidr in var.data_egress_cidr_blocks : can(cidrnetmask(cidr))])
    error_message = "Every entry in data_egress_cidr_blocks must be a valid IPv4 CIDR block."
  }
}

variable "gateway_endpoint_services" {
  description = "Gateway VPC endpoint services to create and associate with the private and data route tables. Supported values are s3 and dynamodb."
  type        = set(string)
  default     = ["s3", "dynamodb"]

  validation {
    condition     = alltrue([for service in var.gateway_endpoint_services : contains(["s3", "dynamodb"], service)])
    error_message = "gateway_endpoint_services may only contain s3 and/or dynamodb."
  }
}

variable "interface_endpoint_services" {
  description = "Interface VPC endpoint service short names to create in the private subnets, for example ssm, ecr.api, logs, secretsmanager, kms."
  type        = set(string)
  default     = []
}

variable "interface_endpoint_private_dns" {
  description = "Enable private DNS for interface VPC endpoints. Disable only if a service does not support private DNS."
  type        = bool
  default     = true
}

variable "enable_flow_logs" {
  description = "Send VPC flow logs to a CloudWatch Logs log group. This incurs CloudWatch ingestion and storage charges."
  type        = bool
  default     = false
}

variable "flow_logs_retention_days" {
  description = "Retention period in days for the VPC flow log group."
  type        = number
  default     = 30

  validation {
    condition     = contains([0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.flow_logs_retention_days)
    error_message = "flow_logs_retention_days must be a retention value supported by CloudWatch Logs."
  }
}

variable "flow_logs_traffic_type" {
  description = "Type of traffic to capture in VPC flow logs: ALL, ACCEPT, or REJECT."
  type        = string
  default     = "ALL"

  validation {
    condition     = contains(["ALL", "ACCEPT", "REJECT"], var.flow_logs_traffic_type)
    error_message = "flow_logs_traffic_type must be one of: ALL, ACCEPT, REJECT."
  }
}

variable "tags" {
  description = "Tags applied to every resource created by the module."
  type        = map(string)
  default     = {}
}
