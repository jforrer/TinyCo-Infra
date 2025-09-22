resource "random_string" "kv_name_suffix" {
  length  = 5
  special = false
  upper   = false
}

resource "azurerm_key_vault" "main" {
  name                        = "kv-${var.org_prefix}-${var.environment}-${random_string.kv_name_suffix.result}"
  location                    = azurerm_resource_group.main.location
  resource_group_name         = azurerm_resource_group.main.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = var.sku_name
  soft_delete_retention_days  = 7

  tags = local.common_tags
}

resource "azurerm_key_vault_access_policy" "itops_policy" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azuread_group.itops_azure_group.object_id

  key_permissions         = var.itops_key_permissions
  secret_permissions      = var.itops_secret_permissions
  certificate_permissions = var.itops_certificate_permissions

}

resource "azurerm_key_vault_access_policy" "sre_policy" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azuread_group.sre_group.object_id

  key_permissions         = var.sre_key_permissions
  secret_permissions      = var.sre_secret_permissions
  certificate_permissions = var.sre_certificate_permissions
}





    