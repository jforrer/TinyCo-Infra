output "resource_group_name" {
  description = "The name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "resource_group_id" {
  description = "The ID of the resource group"
  value       = azurerm_resource_group.main.id
}

output "resource_group_location" {
  description = "The location of the resource group"
  value       = azurerm_resource_group.main.location
}

output "resource_group_tags" {
  description = "Applied of the resource group"
  value       = azurerm_resource_group.main.tags
}

output "key_vault_name" {
  description = "The name of the Key Vault"
  value       = azurerm_key_vault.main.name
}

output "key_vault_id" {
  description = "The ID of the Key Vault"
  value       = azurerm_key_vault.main.id
}

output "key_vault_uri" {
  description = "URI of the Azure Key Vault"
  value       = azurerm_key_vault.main.vault_uri
}

output "itops_azure_group_id" {
  description = "Object ID of the ITOps Azure Admin group"
  value       = data.azuread_group.itops_azure_group.object_id
}

output "sre_group_id" {
  description = "Object ID of the SRE Azure AD group"
  value       = data.azuread_group.sre_group.object_id
}