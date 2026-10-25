variable "region" {
  description = "AWS region to deploy the example network into."
  type        = string
  default     = "us-east-1"
}

variable "name" {
  description = "Name prefix for all network resources."
  type        = string
  default     = "lab"
}

variable "cidr_block" {
  description = "IPv4 CIDR block for the VPC."
  type        = string
  default     = "10.20.0.0/16"
}

variable "az_count" {
  description = "Number of availability zones to use."
  type        = number
  default     = 3
}

variable "nat_gateway_strategy" {
  description = "NAT strategy: per_az, single, or none."
  type        = string
  default     = "per_az"
}

variable "web_ingress_cidr_blocks" {
  description = "CIDRs allowed to reach the web tier."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "interface_endpoint_services" {
  description = "Interface VPC endpoint service names to create."
  type        = set(string)
  default = [
    "ssm",
    "ssmmessages",
    "ec2messages",
    "logs",
    "secretsmanager",
  ]
}

variable "enable_flow_logs" {
  description = "Send VPC flow logs to CloudWatch Logs."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default = {
    Environment = "lab"
    ManagedBy   = "terraform"
  }
}
