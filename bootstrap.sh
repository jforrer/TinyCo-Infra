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

# Enable Tailscale SSH and join with tag for ACL targeting
tailscale up --ssh --advertise-tags=tag:ssh-enabled --authkey="${data.azurerm_key_vault_secret.tailscale_auth.value}"
EOF
)
