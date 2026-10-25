# iac-labs

Terraform building blocks for infrastructure provisioning.

## Layout

```
modules/
  network/          Reusable AWS 3-tier VPC module
examples/
  network/          Runnable example that calls the module
```

## Quick start

```bash
cd examples/network
terraform init
terraform plan -var-file=terraform.tfvars.example
terraform apply -var-file=terraform.tfvars.example
```

The example creates a /16 VPC with public, private, and isolated data subnets
across three availability zones, one NAT gateway per AZ, tier security groups,
S3/DynamoDB gateway endpoints, and five interface endpoints.

## The network module

See [`modules/network/README.md`](modules/network/README.md) for the full input
and output reference. Highlights:

- Deterministic subnet addressing (`[public][private][data]`) with optional
  explicit CIDR overrides.
- `per_az`, `single`, or `none` NAT strategies.
- Pre-wired security groups for web, app, data, and interface endpoints.
- Baseline NACLs and default security group hardening.
- Gateway and interface VPC endpoints so private workloads can reach AWS APIs
  without NAT.
- Optional CloudWatch VPC flow logs.

## Conventions

- Terraform `>= 1.5.0`, AWS provider `>= 5.0, < 7.0`.
- All resources are tagged with the caller's `tags`; every resource also gets a
  `Name` derived from the module's `name` prefix.
- Modules do not configure providers; the calling root module owns provider and
  backend configuration.
