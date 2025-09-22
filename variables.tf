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