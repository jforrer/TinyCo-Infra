locals {
  resource_group_name = "rg-${var.org_prefix}-infra-${var.environment}-${var.location}"


  common_tags = {
    Environment    = var.environment
    CostCenter     = var.cost_center
    Owner          = var.resource_owner
    Project        = "TinyCo-Infrastructure"
    DeployedBy     = "Terraform"
    DeploymentDate = formatdate("YYYY-MM-DD", timestamp())
  }
}

resource "azurerm_resource_group" "main" {
  name     = local.resource_group_name
  location = var.location

  tags = local.common_tags

}