# Provider Variables
"client_id"       = ""
"client_secret"   = ""
"tenant_id"       = ""
"subscription_id" = ""
# Common Variables              
"resource_prefix" = "terraformtest"
"environment"     = "production"
"creation_mode"   = "terraform"
# Resource Group variables
"resource_group_location" = "Australia Southeast"
# Vnet Variables
"vnet_address_space" = "10.2.0.0/16"
#Subnet Variables
"vm_subnets" = ["10.2.1.0/24","10.2.2.0/24"]

# VM variables
"vm_size"       = "Standard_B1s"
"vmadminname"   = "vmadmin" # ssh vmadmin@23.101.239.184 of vm
"vmOSpublisher" = "Canonical"
"vmOSoffer"     = "UbuntuServer"
"vmOSsku"       = "16.04-LTS"
"vmOSversion"   = "latest"
"vm_count"      = 3

