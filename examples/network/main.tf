provider "aws" {
  region = var.region
}

module "network" {
  source = "../../modules/network"

  name                 = var.name
  cidr_block           = var.cidr_block
  az_count             = var.az_count
  nat_gateway_strategy = var.nat_gateway_strategy

  web_ingress_cidr_blocks = var.web_ingress_cidr_blocks
  app_ingress_ports       = [8080]
  data_ingress_ports      = [5432]

  interface_endpoint_services = var.interface_endpoint_services
  enable_flow_logs            = var.enable_flow_logs

  tags = var.tags
}
