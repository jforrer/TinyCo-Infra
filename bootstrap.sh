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

# Wait for managed identity with retry logic
echo "Waiting for managed identity to be ready..."
for i in {1..10}; do
    if az login --identity 2>/dev/null; then 
        echo "Managed identity authenticated successfully"
        break
    fi
    echo "Managed identity not ready, attempt $i/10"
    sleep 30
    if [ $i -eq 10 ]; then
        echo "ERROR: Managed identity failed after 10 attempts"
        exit 1
    fi
done

# Get Tailscale auth key with validation
echo "Retrieving Tailscale auth key from Key Vault..."
if ! AUTH_KEY=$(az keyvault secret show --name "tailscale-auth-key" --vault-name "${key_vault_name}" --query value -o tsv 2>/dev/null); then
    echo "ERROR: Cannot access Key Vault secret 'tailscale-auth-key'"
    echo "Vault: ${key_vault_name}"
    exit 1
fi

# Validate auth key is not empty
if [ -z "$AUTH_KEY" ] || [ "$AUTH_KEY" = "null" ]; then
    echo "ERROR: Auth key is empty or null"
    exit 1
fi

# Join Tailscale network
echo "Successfully retrieved auth key, joining Tailscale network..."
if tailscale up --authkey="$AUTH_KEY" --accept-routes; then
    echo "Tailscale setup completed successfully!"
else
    echo "ERROR: Failed to join Tailscale network"
    exit 1
fi

# Create status file
echo "Bootstrap completed successfully at $(date)" > /tmp/bootstrap-complete
echo "Tailscale status:" >> /tmp/bootstrap-complete
tailscale status >> /tmp/bootstrap-complete 2>&1