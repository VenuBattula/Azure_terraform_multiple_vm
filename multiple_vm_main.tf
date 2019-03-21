terraform {
  required_version = ">= 0.11.0"
}
provider "azurerm" {
  #version        = "1.23.0" #provider.azurerm v1.23.0
  client_id       = "${var.client_id}"
  client_secret   = "${var.client_secret}"
  tenant_id       = "${var.tenant_id}"
  subscription_id = "${var.subscription_id}"
}

# Create a resource group if it doesn’t exist
resource "azurerm_resource_group" "terraform_resource_group" {
  name     = "${var.resource_prefix}-resource_group"
  location = "${var.resource_group_location}"

  tags = {
    environment = "${var.environment}"
  }

  tags = {
    creation_mode = "${var.creation_mode}"
  }
}

# Create virtual network
resource "azurerm_virtual_network" "terraform_vnet" {
  name                = "${var.resource_prefix}-vnet"
  location            = "${var.resource_group_location}"
  resource_group_name = "${azurerm_resource_group.terraform_resource_group.name}"
  address_space       = ["${var.vnet_address_space}"]
}

# Create subnet

resource "azurerm_subnet" "terraform_subnet" {
  name                      = "${var.resource_prefix}-${substr(var.vm_subnets[count.index], 0, length(var.vm_subnets[count.index])-3)}-subnet"
  resource_group_name       = "${azurerm_resource_group.terraform_resource_group.name}"
  virtual_network_name      = "${azurerm_virtual_network.terraform_vnet.name}"
  address_prefix            = "${var.vm_subnets[count.index]}"
  network_security_group_id = "${azurerm_network_security_group.terraform_nsg.id}"
  count                     = "${length(var.vm_subnets)}"
}
# output of subnet names
output "myOutput" {
   value = "${azurerm_subnet.terraform_subnet.*.name}"
}
# Create Network Security Group and rule
resource "azurerm_network_security_group" "terraform_nsg" {
  name                = "${var.resource_prefix}-nsg"
  location            = "${azurerm_resource_group.terraform_resource_group.location}"
  resource_group_name = "${azurerm_resource_group.terraform_resource_group.name}"
}

resource "azurerm_network_security_rule" "terraform_nsg_rule" {
  name                        = "${var.resource_prefix}-ssh"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "TCP"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = "${azurerm_resource_group.terraform_resource_group.name}"
  network_security_group_name = "${azurerm_network_security_group.terraform_nsg.name}"
}
# Create network interface[NIC]
resource "azurerm_network_interface" "terraform_NIC" {
  name                       = "${var.resource_prefix}-${count.index+1}nic"
  location                   = "${azurerm_resource_group.terraform_resource_group.location}"
  resource_group_name        = "${azurerm_resource_group.terraform_resource_group.name}"
  count                      = "${var.vm_count}"
  #network_security_group_id = "${azurerm_network_security_group.terraform_nsg.id}"           /* moved it to subnet level */

  ip_configuration {
    name                          = "${var.resource_prefix}-ipconfig"
    subnet_id                     = "${azurerm_subnet.terraform_subnet.*.id[count.index%2]}"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = "${azurerm_public_ip.terraform_PIP.*.id[count.index]}"
  }

  tags = {
    environment = "${var.environment}"
  }
}

# Create public IPs
resource "azurerm_public_ip" "terraform_PIP" {
  name                = "${var.resource_prefix}-${count.index+1}-pip" #%2d will interpolate the count to 2 decimals
  location            = "${var.resource_group_location}"
  resource_group_name = "${azurerm_resource_group.terraform_resource_group.name}"
  count               = "${var.vm_count}"

  #allocation_method = "Dynamic"
  allocation_method  = "${var.environment == "production" ? "Dynamic" : "Static"}"

  tags = {
    environment = "${var.environment}"
  }
}



#******************** Required for virtual machine boot_diagnostics ********************************#
# Generate random text for a unique storage account name 
resource "random_id" "randomId" {
  keepers = {
    # Generate a new ID only when a new resource group is defined
    resource_group = "${azurerm_resource_group.terraform_resource_group.name}"
  }

  byte_length = 4
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "terraform_storrage_account" {
  name                     = "${var.resource_prefix}${random_id.randomId.hex}"
  resource_group_name      = "${azurerm_resource_group.terraform_resource_group.name}"
  location                 = "${var.resource_group_location}"
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags {
    environment = "${var.environment}"
  }
}

#********************** Create virtual machine *****************************#
resource "azurerm_virtual_machine" "terraform_vm" {
  count                 = "${var.vm_count}"
  name                  = "${var.resource_prefix}-${count.index+1}-vm"
  location              = "${azurerm_resource_group.terraform_resource_group.location}"
  resource_group_name   = "${azurerm_resource_group.terraform_resource_group.name}"
  network_interface_ids = ["${azurerm_network_interface.terraform_NIC.*.id[count.index]}"]
  vm_size               = "${var.vm_size}"
  availability_set_id   = "${azurerm_availability_set.terraform_availability_set.id}"
  depends_on            = ["azurerm_network_interface.terraform_NIC", "azurerm_availability_set.terraform_availability_set"]

  storage_image_reference {
    publisher = "${var.vmOSpublisher}"
    offer     = "${var.vmOSoffer}"
    sku       = "${var.vmOSsku}"
    version   = "${var.vmOSversion}"
  }

  storage_os_disk {
      
      name              = "${var.resource_prefix}-${count.index+1}osdisk"
      caching           = "ReadWrite"
      create_option     = "FromImage"
      managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "${var.resource_prefix}${count.index+1}-system"
    admin_username = "${var.vmadminname}"

    #admin_password = "${var.vmadminpassword}" # as we will ssh into the system, password is not required.
  }

  os_profile_linux_config {
    disable_password_authentication = true

    ssh_keys = [{
      path     = "/home/${var.vmadminname}/.ssh/authorized_keys"
      key_data = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDagpkY1oBjCIJu527RRW6RXy6zplJ904v3+xkdfn+qb5lsMcmK8N6sHADgba7+XmZvrEb6/5vlqBfcARueFQFYtvLum80YhShVrwMSzpjwob3QEnyaQfnRKrZuejqT0VURog+pUK1hOFDlBMJhwrwnq/cAEBzoSqbpofZzG9jsoWO53EIvlfg2qeuR7lLMyRHCvuJnXpgCg8tmFHWjkXQhrMIzNYE2AEF9yyQPeq95/pxKH+GK1S5bZoM7AkdM0XL49lQ8/zR0OwvSUL2QtQaH6gyS0+luFtFC2c+/edc39qLuALFLD1DiW6iZPD1V5cpxGFA6zVjHRMisMt1Uc16Z 777232@AMBAUS00366.local" # this is the public key
    }]
  }

  boot_diagnostics {
    enabled     = "true"
    storage_uri = "${azurerm_storage_account.terraform_storrage_account.primary_blob_endpoint}"
  }

  tags {
    environment = "${var.environment}"
  }
}

resource "azurerm_availability_set" "terraform_availability_set" {
  name                         = "${var.resource_prefix}availabilityset"
  location                     = "${azurerm_resource_group.terraform_resource_group.location}"
  resource_group_name          = "${azurerm_resource_group.terraform_resource_group.name}"
  managed                      = true
  platform_fault_domain_count  = 2
  platform_update_domain_count = 5

  tags = {
    environment = "${var.environment}"
  }
}

