# vm.tf - Azure Virtual Machine with Tailscale and Azure AD SSH

# Managed Identity for VM to access Key Vault
resource "azurerm_user_assigned_identity" "vm_identity" {
  name                = "id-vm-${var.org_prefix}-${var.environment}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = local.common_tags
}

# Grant VM identity access to Key Vault secrets
resource "azurerm_key_vault_access_policy" "vm_policy" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_user_assigned_identity.vm_identity.principal_id

  secret_permissions = ["Get"]
}

# Virtual Machine
resource "azurerm_linux_virtual_machine" "main" {
  name                = "vm-${var.org_prefix}-${var.environment}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = "Standard_B1s"
  admin_username      = "azureuser"
  
  disable_password_authentication = true

  network_interface_ids = [azurerm_network_interface.main.id]

  admin_ssh_key {
    username   = "azureuser"
    public_key = var.ssh_public_key
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.vm_identity.id]
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  # Embedded bootstrap script
  custom_data = base64encode(<<-EOF
#!/bin/bash
# Embedded bootstrap script for TinyCo VM

set -e

# Update system
apt-get update
apt-get upgrade -y

# Install required packages
apt-get install -y curl wget unzip jq

# Install Azure CLI
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
if ! AUTH_KEY=$(az keyvault secret show --name "tailscale-auth-key" --vault-name "${azurerm_key_vault.main.name}" --query value -o tsv 2>/dev/null); then
    echo "ERROR: Cannot access Key Vault secret 'tailscale-auth-key'"
    echo "Vault: ${azurerm_key_vault.main.name}"
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
EOF
  )

  tags = local.common_tags
}

# Azure AD SSH Extension
resource "azurerm_virtual_machine_extension" "aad_ssh" {
  name                 = "AADSSHLoginForLinux"
  virtual_machine_id   = azurerm_linux_virtual_machine.main.id
  publisher            = "Microsoft.Azure.ActiveDirectory"
  type                 = "AADSSHLoginForLinux"
  type_handler_version = "1.0"

  tags = local.common_tags
}