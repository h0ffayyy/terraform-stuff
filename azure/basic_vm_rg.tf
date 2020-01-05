/* 
  This template will create a resource group with a 
  Standard_B2s VM and all associated resources.
*/

# use default subscription, tenant, etc.
provider "azurerm" {
  version = "=1.38.0"
}

variable "prefix" {
  default     = "NewRG"
  type        = string
  description = "The prefix used for all resources"
}

variable "sshpubkey" {
  type        = string
  description = "The SSH public key for the VM admin user"
}

variable "osusername" {
  type        = string
  default     = "cloudadmin"
  description = "The username for the VM user"
}

resource "azurerm_resource_group" "main" {
  name     = "${var.prefix}-resources"
  location = "South Central US"
}

resource "azurerm_virtual_network" "main" {
  name                  = "${var.prefix}-vnet"
  address_space         = ["10.0.0.0/16"]
  location              = "${azurerm_resource_group.main.location}"
  resource_group_name   = "${azurerm_resource_group.main.name}"
}

resource "azurerm_subnet" "internal" {
  name                  = "internal"
  resource_group_name   = "${azurerm_resource_group.main.name}"
  virtual_network_name  = "${azurerm_virtual_network.main.name}"
  address_prefix        = "10.0.2.0/24"
}

resource "azurerm_public_ip" "main" {
  name                    = "${azurerm_resource_group.main.name}-pubip"
  location                = "${azurerm_resource_group.main.location}"
  resource_group_name     = "${azurerm_resource_group.main.name}"
  allocation_method       = "Dynamic"
  idle_timeout_in_minutes = 30
}

resource "azurerm_network_interface" "main" {
  name                      = "${var.prefix}-nic"
  location                  = "${azurerm_resource_group.main.location}"
  resource_group_name       = "${azurerm_resource_group.main.name}"
  network_security_group_id = "${azurerm_network_security_group.main.id}"

  ip_configuration {
    name                          = "ip1"
    subnet_id                     = "${azurerm_subnet.internal.id}"
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.2.5"
    public_ip_address_id          = "${azurerm_public_ip.main.id}"
  }
}

# get public ip for nsg ssh rule
data "http" "mypubip" {
  url = "https://ipv4.icanhazip.com"
}

resource "azurerm_network_security_group" "main" {
  name                  = "${azurerm_resource_group.main.name}-nsg1"
  location              = "${azurerm_resource_group.main.location}"
  resource_group_name   = "${azurerm_resource_group.main.name}"

  security_rule {
    name                        = "AllowSSH"
    priority                    = 100
    direction                   = "Inbound"
    access                      = "Allow"
    protocol                    = "Tcp"
    source_port_range           = "*"
    destination_port_range      = "22"
    source_address_prefix       = "${chomp(data.http.mypubip.body)}/32"
    destination_address_prefix  = "*"
  }
}

resource "azurerm_virtual_machine" "main" {
  name                  = "${var.prefix}vm1"
  location              = "${azurerm_resource_group.main.location}"
  resource_group_name   = "${azurerm_resource_group.main.name}"
  network_interface_ids = ["${azurerm_network_interface.main.id}"]
  vm_size               = "Standard_B2s"

  delete_os_disk_on_termination     = true
  delete_data_disks_on_termination  = true

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name              = "myosdisk01"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name   = "${var.prefix}vm1"
    admin_username  = "${var.osusername}"
  }
  os_profile_linux_config {
    disable_password_authentication = true
    ssh_keys {
      key_data = "${var.sshpubkey}"
      path = "/home/${var.osusername}/.ssh/authorized_keys"
    }
  }
  tags = {
    environment = "testing"
  }
}

data "azurerm_public_ip" "main" {
  name                = "${azurerm_public_ip.main.name}"
  resource_group_name = "${azurerm_virtual_machine.main.resource_group_name}"
}

output "public_ip_address" {
  value = "${data.azurerm_public_ip.main.ip_address}"
}