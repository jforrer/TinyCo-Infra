provider "azurerm" {
  features {}
}
provider "tailscale" {
  oauth_client_id     = data.azurerm_key_vault_secret.tailscale_oauth_client_id.value
  oauth_client_secret = data.azurerm_key_vault_secret.tailscale_oauth_client_secret.value
}
