# Network example

Creates a three-tier, three-AZ VPC using the module in `../../modules/network`.

## Run it

```bash
terraform init
terraform plan -var-file=terraform.tfvars.example
terraform apply -var-file=terraform.tfvars.example
```

Then inspect the exported IDs:

```bash
terraform output
```

## What you get

- VPC `10.20.0.0/16` with public, private, and isolated data subnets in three AZs
- Internet gateway and one NAT gateway per AZ
- Web, app, data, and endpoint security groups
- Baseline NACLs and a hardened default security group
- S3 and DynamoDB gateway endpoints
- SSM, Logs, and Secrets Manager interface endpoints
- Optional VPC flow logs (enabled in `terraform.tfvars.example`)

## Costs and cleanup

NAT gateways, interface endpoints, and flow logs incur hourly charges. Tear the
example down when you are finished:

```bash
terraform destroy -var-file=terraform.tfvars.example
```
