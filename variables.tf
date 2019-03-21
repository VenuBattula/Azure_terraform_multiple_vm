    # Provider Variables
    variable "client_id" {}
    variable "client_secret" {}
    variable "tenant_id" {}
    variable "subscription_id" {}
    # Common Variables
    variable "resource_prefix" {
       default = "terraform"
    }
    variable "creation_mode" {
       default = "terraform"
    }
    variable "environment" {
       default = "production"
    }
    
    # Resource group variables#
    variable "resource_group_location" {
       default = "Australia Southeast"
    }

    # Vnet Varibles#
    variable "vnet_address_space" {}
    
    # Subnet Variables
    variable "vm_subnets" { 
        type="list"
    }
    # VM Variables #

     variable "vm_size" {
        default = "Standard_B1s"
     }
     variable "vmadminname" {
         default = "vmadmin"
      }
      
      variable "vmOSpublisher" {
         default = "Canonical"
      }

      variable "vmOSoffer" {
         default = "UbuntuServer"
      }

      variable "vmOSsku" {
         default = "16.04-LTS"
      }

      variable "vmOSversion" {
         default = "latest"
      }
      variable "vm_count" {
         default =   "1"
      }