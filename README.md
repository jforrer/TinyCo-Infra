## Components

### Azure Infrastructure
- **Resource Group**: `rg-tinyco-infra-dev-eastus`
- **Virtual Network**: `10.0.0.0/16` with `10.0.1.0/24` subnet
- **Virtual Machine**: Ubuntu 22.04 with Tailscale agent
- **Key Vault**: Secure storage for Tailscale credentials and SSH keys
- **Network Security Group**: Tailscale UDP port configuration

### Tailscale Integration
- **SSO**: Microsoft Entra ID integration (`TinyCoDDG.onmicrosoft.com`)
- **ACL Management**: Network access control via `tailscale-acl.json`
- **Subnet Routing**: Azure VM advertises `10.0.1.0/24` to Tailscale network
- **SCIM**: Automatic group synchronization with Entra ID

## Prerequisites

- Azure CLI
- Terraform >= 1.0
- Azure subscription access
- Tailscale OAuth credentials in Key Vault

## Usage

```bash
# Login and set subscription
az login
export ARM_SUBSCRIPTION_ID="your-subscription-id"

# Set SSH public key
export TF_VAR_ssh_public_key="your-ssh-public-key"

# Deploy infrastructure
terraform init
terraform plan
terraform apply
```

## File Structure

- `main.tf` - Provider configurations
- `variables.tf` - Input variables and validation
- `terraform.tfvars` - Environment-specific values
- `resource-group.tf` - Resource group and tagging
- `networking.tf` - Virtual network configuration
- `key-vault.tf` - Key Vault with team-based access policies
- `vm.tf` - Virtual machine with Tailscale bootstrap
- `tailscale-acl.tf` - Tailscale ACL resource
- `tailscale-acl.json` - Network access control policies
- `data.tf` - Data sources for existing resources
- `outputs.tf` - Resource output values

## Network Access Control

Access tiers defined in `tailscale-acl.json`:
- **ITOps**: Full network access (`*:*`)
- **SRE/Security/Backend**: Infrastructure access (`10.0.1.0/24:*`)
- **Frontend**: Web services only (`10.0.1.0/24:80,443`)
## Permissions Required

- Azure Contributor role (use PIM)
