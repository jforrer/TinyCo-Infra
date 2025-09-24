resource "azurerm_user_assigned_identity" "vm_identity" {
  name                = "id-vm-${var.org_prefix}-${var.environment}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = local.common_tags
}

resource "azurerm_key_vault_access_policy" "vm_policy" {
  key_vault_id       = azurerm_key_vault.main.id
  tenant_id          = data.azurerm_client_config.current.tenant_id
  object_id          = azurerm_user_assigned_identity.vm_identity.principal_id
  secret_permissions = ["Get"]
}

data "azurerm_key_vault_secret" "tailscale_auth" {
  name         = "tailscale-auth-key"
  key_vault_id = azurerm_key_vault.main.id
}

resource "azurerm_linux_virtual_machine" "main" {
  name                            = "vm-${var.org_prefix}-${var.environment}"
  resource_group_name             = azurerm_resource_group.main.name
  location                        = azurerm_resource_group.main.location
  size                            = "Standard_B1s"
  admin_username                  = "azureuser"
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.main.id]

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

  custom_data = base64encode(<<-EOF
#!/bin/bash
set -e
exec > >(tee -a /tmp/bootstrap.log) 2>&1

# Give cloud-init time to finish, then robust apt lock handling
sleep 90

wait_for_apt() {
  while \
    sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || \
    sudo fuser /var/lib/dpkg/lock >/dev/null 2>&1 || \
    sudo fuser /var/lib/apt/lists/lock >/dev/null 2>&1
  do
    echo "Waiting for apt/dpkg locks to be released..."
    sleep 5
  done
}

wait_for_apt
apt-get update

wait_for_apt
apt-get install -y curl wget unzip jq

wait_for_apt
curl -sL https://aka.ms/InstallAzureCLIDeb | bash

wait_for_apt
curl -fsSL https://tailscale.com/install.sh | sh

tailscale up --ssh --advertise-tags=tag:ssh-enabled --authkey="${data.azurerm_key_vault_secret.tailscale_auth.value}"
EOF
  )


  tags = local.common_tags
}
