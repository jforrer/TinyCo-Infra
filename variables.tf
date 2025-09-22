variable "environment" {
  description = "The environment for the deployment (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "location" {
  description = "The Azure region where resources will be deployed"
  type        = string
  default     = "eastus"

}

variable "org_prefix" {
  description = "Company/organization prefix for resource naming"
  type        = string
  default     = "tinyco"

  validation {
    condition     = length(var.org_prefix) > 0
    error_message = "Organization prefix cannot be empty."
  }
}

variable "cost_center" {
  description = "Cost center identifier for billing purposes"
  type        = string
  default     = "ITOps"
}

variable "resource_owner" {
  description = "primary contact/owner for the resources"
  type        = string
  default     = "ITOps-Team"
}

variable "sku_name" {
  description = "The Name of the SKU used for this Key Vault"
  type        = string
  default     = "standard"
}

variable "itops_key_permissions" {
  description = "Key permissions for ITOps team"
  type        = list(string)
  default = [
    "Get", "List", "Update", "Create", "Import", "Delete", "Recover",
    "Backup", "Restore", "Decrypt", "Encrypt", "UnwrapKey", "WrapKey",
    "Verify", "Sign", "Purge"
  ]
}

variable "itops_secret_permissions" {
  description = "Secret permissions for ITOps team"
  type        = list(string)
  default = [
    "Get", "List", "Set", "Delete", "Recover", "Backup", "Restore", "Purge"
  ]
}

variable "itops_certificate_permissions" {
  description = "Certificate permissions for ITOps team"
  type        = list(string)
  default = [
    "Get", "List", "Update", "Create", "Import", "Delete", "Recover",
    "Backup", "Restore", "ManageContacts", "ManageIssuers", "GetIssuers",
    "ListIssuers", "SetIssuers", "DeleteIssuers", "Purge"
  ]
}

variable "sre_key_permissions" {
  description = "Key permissions for SRE team"
  type        = list(string)
  default     = ["Get", "List", "Decrypt", "Encrypt", "Create", "Update"]
}

variable "sre_secret_permissions" {
  description = "Secret permissions for SRE team"
  type        = list(string)
  default     = ["Get", "List", "Set", "Delete"]
}

variable "sre_certificate_permissions" {
  description = "Certificate permissions for SRE team"
  type        = list(string)
  default     = ["Get", "List", "Import", "Update"]
}
