# AWS network module

Reusable AWS networking for a three-tier, multi-AZ workload. It provisions the
VPC, subnet tiers, routing, NAT, baseline security controls, VPC endpoints, and
optional flow logs. Application and data resources plug into the exported IDs.

## What it creates

```
Internet
   │
   ▼
┌──────────────────────────── VPC 10.20.0.0/16 ────────────────────────────┐
│                                                                          │
│  Public tier (one subnet per AZ)                                         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                       │
│  │  public-1a  │  │  public-1b  │  │  public-1c  │  ALB, NAT, bastion    │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘                       │
│         │ IGW            │ IGW            │ IGW                          │
│                                                                          │
│  Private tier (one subnet per AZ, route to NAT)                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                       │
│  │ private-1a  │  │ private-1b  │  │ private-1c  │  app, containers      │
│  └─────────────┘  └─────────────┘  └─────────────┘                       │
│                                                                          │
│  Data tier (one subnet per AZ, no default route)                         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                       │
│  │  data-1a    │  │  data-1b    │  │  data-1c    │  RDS, ElastiCache     │
│  └─────────────┘  └─────────────┘  └─────────────┘                       │
│                                                                          │
│  S3 / DynamoDB gateway endpoints, optional interface endpoints           │
└──────────────────────────────────────────────────────────────────────────┘
```

Tier security groups are pre-wired:

- `web` accepts `web_ingress_ports` from `web_ingress_cidr_blocks` and can only
  send traffic to `app` on `app_ingress_ports`.
- `app` accepts traffic from `web`, reaches `data` on `data_ingress_ports`, and
  has HTTPS/DNS egress for VPC endpoints and (optionally) the internet.
- `data` accepts only `app` traffic on `data_ingress_ports` and has HTTPS/DNS
  egress for endpoints such as KMS and Secrets Manager.
- `endpoints` accepts HTTPS from inside the VPC.

The VPC default security group is stripped of rules unless
`manage_default_security_group = false`. Baseline network ACLs back up the
security groups and can be disabled with `create_network_acls = false`.

## Usage

```hcl
module "network" {
  source = "../../modules/network"

  name                 = "prod"
  cidr_block           = "10.20.0.0/16"
  az_count             = 3
  nat_gateway_strategy = "per_az"

  web_ingress_cidr_blocks = ["203.0.113.0/24"]
  app_ingress_ports       = [8080]
  data_ingress_ports      = [5432]

  interface_endpoint_services = [
    "ssm",
    "ssmmessages",
    "ec2messages",
    "logs",
    "secretsmanager",
  ]

  enable_flow_logs = true

  tags = {
    Environment = "prod"
    ManagedBy   = "terraform"
  }
}
```

A runnable root configuration lives in [`examples/network`](../../examples/network).

```bash
cd examples/network
terraform init
terraform plan -var-file=terraform.tfvars.example
```

## Design notes

- Subnets are carved deterministically from `cidr_block` as
  `[public][private][data]`, so numbering stays stable when tiers are scaled.
  Supply explicit CIDR lists if you need a different address plan; they must be
  IPv4 network CIDRs inside `cidr_block`, one per AZ.
- `nat_gateway_strategy = "per_az"` is the default and avoids a cross-AZ
  dependency. Use `"single"` to cut NAT cost, or `"none"` for endpoint-only
  private workloads.
- The data tier has no default route. It can still use gateway endpoints (S3,
  DynamoDB) and interface endpoints.
- The module is IPv4 only. IPv6 and Transit Gateway attachments are deliberately
  left to the caller.
- VPC flow logs are off by default to avoid surprise CloudWatch costs.

## Wiring workloads

| Workload | Subnets | Security group |
|----------|---------|----------------|
| ALB / public ingress | `subnet_ids.public` | `security_group_ids.web` |
| Application compute / containers | `subnet_ids.private` | `security_group_ids.app` |
| RDS, ElastiCache, other data stores | `subnet_ids.data` | `security_group_ids.data` |

Use `route_table_ids` when you need to attach additional gateway endpoints or
appliance routes.

## Extending access

The security groups are a working baseline, not a complete policy. Add rules
against the exported group IDs:

```hcl
resource "aws_vpc_security_group_ingress_rule" "bastion_ssh" {
  security_group_id = module.network.security_group_ids.web
  description       = "SSH from the office"
  cidr_ipv4         = "203.0.113.0/24"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
}
```

All tiers can reach IMDS, Amazon Time Sync, and DNS. The web tier reaches app,
app reaches data, and the app and data tiers can use VPC endpoints. Add egress
for any other ports your workloads need. The data tier has no default route, so
extra egress rules do not create internet access on their own.

`name` is used verbatim in IAM and CloudWatch Logs resource names. Keep it unique
per account when flow logs are enabled.

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5.0 |
| aws | >= 5.0, < 7.0 |

## Inputs

| Name | Description | Type | Default |
|------|-------------|------|---------|
| name | Name prefix for all resources | `string` | n/a |
| cidr_block | VPC IPv4 CIDR | `string` | `"10.0.0.0/16"` |
| az_count | Number of AZs | `number` | `3` |
| availability_zones | Explicit AZ names (overrides az_count) | `list(string)` | `null` |
| subnet_newbits | Bits used to derive subnet CIDRs | `number` | `4` |
| public_subnet_cidrs | Explicit public CIDRs, one per AZ | `list(string)` | `null` |
| private_subnet_cidrs | Explicit private CIDRs, one per AZ | `list(string)` | `null` |
| data_subnet_cidrs | Explicit data CIDRs, one per AZ | `list(string)` | `null` |
| map_public_ip_on_launch | Auto-assign public IPs in public subnets | `bool` | `false` |
| nat_gateway_strategy | `per_az`, `single`, or `none` | `string` | `"per_az"` |
| create_network_acls | Create baseline NACLs | `bool` | `true` |
| manage_default_security_group | Strip rules from the default SG | `bool` | `true` |
| web_ingress_cidr_blocks | CIDRs allowed to reach the web tier | `list(string)` | `["0.0.0.0/0"]` |
| web_ingress_ports | Web tier TCP ports | `list(number)` | `[80, 443]` |
| app_ingress_ports | Ports web may use to reach app | `list(number)` | `[8080]` |
| data_ingress_ports | Ports app may use to reach data | `list(number)` | `[5432]` |
| app_egress_cidr_blocks | CIDRs app may reach on TCP/443 | `list(string)` | `["0.0.0.0/0"]` |
| data_egress_cidr_blocks | CIDRs data may reach on TCP/443 | `list(string)` | `["0.0.0.0/0"]` |
| gateway_endpoint_services | Gateway endpoints to create | `set(string)` | `["s3", "dynamodb"]` |
| interface_endpoint_services | Interface endpoint service names | `set(string)` | `[]` |
| interface_endpoint_private_dns | Enable private DNS on interface endpoints | `bool` | `true` |
| enable_flow_logs | Send flow logs to CloudWatch Logs | `bool` | `false` |
| flow_logs_retention_days | Flow log retention | `number` | `30` |
| flow_logs_traffic_type | `ALL`, `ACCEPT`, or `REJECT` | `string` | `"ALL"` |
| tags | Tags for all resources | `map(string)` | `{}` |

## Outputs

| Name | Description |
|------|-------------|
| vpc_id | VPC ID |
| vpc_arn | VPC ARN |
| vpc_cidr_block | VPC CIDR |
| region | Region the module is deployed into |
| availability_zones | AZs used by the subnets |
| subnet_ids | `{ public, private, data }` lists of subnet IDs |
| subnet_cidr_blocks | `{ public, private, data }` lists of CIDRs |
| internet_gateway_id | Internet gateway ID |
| nat_gateway_ids | NAT gateway IDs |
| nat_gateway_public_ips | NAT elastic IPs |
| route_table_ids | `{ public, private, data }` route table IDs |
| security_group_ids | `{ web, app, data, endpoints }` security group IDs |
| network_acl_ids | `{ public, private, data }` NACL IDs |
| vpc_endpoint_ids | Endpoint IDs keyed by type and service |
| flow_log_id | Flow log ID, or `null` |
