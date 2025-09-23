#!/bin/bash
# bootstrap.sh - TinyCo VM Bootstrap Script

set -e

# Update system
apt-get update
apt-get upgrade -y

# Install required packages
apt-get install -y curl wget unzip jq

# Install Azure CLI (for Key Vault access)
curl -sL https://aka.ms/InstallAzureCLIDeb | bash

# Install Tailscale
curl -fsSL https://tailscale.com/install.sh | sh

# Start and enable Tailscale service
systemctl start tailscaled
systemctl enable tailscaled

# Use the auth key to automatically register the node
tailscale up --auth-key=$(az keyvault secret show --name tailscale-auth-key --vault-name ${key_vault_name} --query value -o tsv)

echo "Bootstrap completed at $(date)" > /tmp/bootstrap-complete