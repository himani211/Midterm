provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

terraform {
  backend "azurerm" {
    resource_group_name  = "RGnew"
    storage_account_name = "himani789"
    container_name       = "container1"
    key                  = "terraform.tfstate"
  }
}

# Resource Group
resource "azurerm_resource_group" "rg2" {
  name     = var.resource_group_name
  location = var.location
}

# Virtual Network
resource "azurerm_virtual_network" "Vnett01" {
  name                = var.vnet_name
  address_space       = var.address_space
  location            = var.location
  resource_group_name = var.resource_group_name
}

# Subnet
resource "azurerm_subnet" "subnet" {
  name                 = var.subnet_name
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.Vnett01.name
  address_prefixes     = var.subnet_address_prefix
}

# Network Security Group
resource "azurerm_network_security_group" "nsg01" {
  name                = var.nsg_name
  location            = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "AllowSSH"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow8000"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "8000"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Public IP Address
resource "azurerm_public_ip" "vm_public_ipaddr11" {
  name                = "vm-public-ip-S3"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Network Interface for Linux VM
resource "azurerm_network_interface" "nic_linux" {
  name                = "nic-linux-vm-S3"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "ipconfig-linux-S3"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm_public_ipaddr11.id
  }
}

# Associate NSG with NIC
resource "azurerm_network_interface_security_group_association" "nic_nsg" {
  network_interface_id      = azurerm_network_interface.nic_linux.id
  network_security_group_id = azurerm_network_security_group.nsg01.id
}

# Linux Virtual Machine
resource "azurerm_linux_virtual_machine" "linux_vm" {
  name                            = "linux-vm-S3"
  resource_group_name             = var.resource_group_name
  location                        = var.location
  size                            = var.vm_size
  admin_username                  = var.vm_admin_username
  admin_password                  = var.vm_admin_password
  disable_password_authentication = false

  network_interface_ids = [azurerm_network_interface.nic_linux.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = var.vm_image_publisher
    offer     = var.vm_image_offer
    sku       = var.vm_image_sku
    version   = var.vm_image_version
  }

  plan {
    name      = var.vm_image_sku
    publisher = var.vm_image_publisher
    product   = var.vm_image_offer
  }

  custom_data = base64encode(<<EOT
#!/bin/bash

# Update the package repository
echo "Updating package repository..."
sudo dnf -y update

# Install epel-release
echo "Installing epel-release..."
sudo dnf -y install epel-release

# Install Docker repository
echo "Adding Docker repository..."
sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

# Install Docker packages
echo "Installing Docker packages..."
sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Start Docker service
echo "Starting Docker service..."
sudo systemctl start docker

# Enable Docker service to start on boot
echo "Enabling Docker service..."
sudo systemctl enable docker

# Verify Docker installation
echo "Verifying Docker installation..."
sudo docker --version && echo "Docker successfully installed." || echo "Docker installation failed."

# Install Maven
echo "Installing Maven..."
sudo dnf install -y maven

# Verify Maven installation
echo "Verifying Maven installation..."
sudo mvn --version && echo "Maven successfully installed." || echo "Maven installation failed."

# Install Ansible
echo "Installing Ansible..."
sudo dnf -y install ansible

# Install Git
echo "Installing Git..."
sudo dnf -y install git

# Install OpenJDK 17
echo "Installing OpenJDK 17..."
sudo dnf -y install java-17-openjdk-devel

# Script completion message
echo "Custom data script execution completed."
EOT
  )
}

# Output Public IP Address
output "vm_public_ip" {
  value = azurerm_public_ip.vm_public_ipaddr11.ip_address
}
