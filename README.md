# TinyCo Infrastructure

Terraform configuration for TinyCo's Azure infrastructure

## Prerequisites

- Azure CLI
- Terraform >= 1.0
- Azure subscription access

## Usage

```bash
# Login and set subscription
az login
export ARM_SUBSCRIPTION_ID="your-subscription-id"

# Deploy infrastructure
terraform init
terraform plan
terraform apply
```

## Structure

- `main.tf` - Provider configuration
- `variables.tf` - Input variables
- `resource-group.tf` - Resource group definition
- `outputs.tf` - Output values
- `terraform.tfvars` - Variable values

## Permissions Required

- Azure Contributor role (use PIM)