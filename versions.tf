terraform {
  required_version = ">= 1.0.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "= 4.45.0"
    }
    tailscale = {
      source  = "tailscale/tailscale"
      version = "~> 0.16" // Latest 0.16.x
    }
  }
}
