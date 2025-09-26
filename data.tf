# data.tf - Data sources for existing resources

# Get current Azure context
data "azurerm_client_config" "current" {}

# Reference existing Entra ID groups (created manually in Entra)
data "azuread_group" "itops_azure_group" {
  display_name     = "PIM-ITOps-AzureAdmin"
  security_enabled = true
}

data "azuread_group" "sre_group" {
  display_name     = "PIM-SRE-CloudCompute"
  security_enabled = true
}

data "azurerm_key_vault_secret" "tailscale_key" {
  name         = "tailscale-auth-key"
  key_vault_id = azurerm_key_vault.main.id
}

data "azurerm_key_vault_secret" "tailscale_oauth_client_id" {
  name         = "tailscale-oauth-client-id"
  key_vault_id = azurerm_key_vault.main.id
}

data "azurerm_key_vault_secret" "tailscale_oauth_client_secret" {
  name         = "tailscale-oauth-client-secret"
  key_vault_id = azurerm_key_vault.main.id
}
