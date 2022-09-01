# Terraform Block
terraform {
  required_version = ">=1.2.8"
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "3.20.0"
     }
  }
}

# Provider Block

 provider "azurerm" {
   features {}
 }
 
 resource "azurerm_resource_group" "test" {
   name     = "kyndryl"
   location = "West US 3"
 }
 
 # Create virtual network

 resource "azurerm_virtual_network" "myvnet" {
  name = "myvnet-1"
  address_space = ["10.0.0.0/16"]
  location = azurerm_resource_group.test.location
  resource_group_name = azurerm_resource_group.test.name   
 }

 # Create Subnet

 resource "azurerm_subnet" "mysubnet" {
  name = "mysubnet-1"
  resource_group_name = azurerm_resource_group.test.name
  virtual_network_name = azurerm_virtual_network.myvnet.name
  address_prefixes = ["10.0.2.0/24"]
 }

 # Create NSG

 resource "azurerm_network_security_group" "nsg" {
  name = "mynsg"
  resource_group_name = azurerm_resource_group.test.name
  location = azurerm_resource_group.test.location
  security_rule {
    name = "Allow-ssh"
    priority = 101
    direction = "Inbound"
    access = "Allow"
    protocol = "Tcp"
    source_port_range = "*"
    destination_port_range = "22"
    source_address_prefix = "*"
    destination_address_prefix = "*"

  }
  security_rule {
    name = "HTTP"
    priority = 102
    direction = "Inbound"
    access = "Allow"
    protocol = "Tcp"
    source_port_range = "*"
    destination_port_range = "80"
    source_address_prefix = "*"
    destination_address_prefix = "*"
  }
 }

 # Subnet Network Security Group Association
 resource "azurerm_subnet_network_security_group_association" "nsgsubnet" {
  subnet_id = azurerm_subnet.mysubnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
   
 }
 
 # Create Network Interface

 resource "azurerm_network_interface" "vmnic" {
  name = "vmnic1"
  location = azurerm_resource_group.test.location
  resource_group_name = azurerm_resource_group.test.name

  ip_configuration {
    name = "internal"
    subnet_id = azurerm_subnet.mysubnet.id
    private_ip_address_allocation = "Dynamic"
    #public_ip_address_id = azurerm_public_ip.publicip.id
  }
   
 }

# Create Network Interface 2

resource "azurerm_network_interface" "myvmnic2" {
  name = "myvmnic"
  location = azurerm_resource_group.test.location
  resource_group_name = azurerm_resource_group.test.name

  ip_configuration {
    name = "internal2"
    subnet_id = azurerm_subnet.mysubnet.id
    private_ip_address_allocation = "Dynamic"
    #public_ip_address_id = azurerm_public_ip.mypublicip.id
  }
}


 # Create virtual Machine

 resource "azurerm_linux_virtual_machine" "linuxvm" {
  name = "linuxvm1"
  computer_name = "devlinux-vm"
  resource_group_name = azurerm_resource_group.test.name
  location = azurerm_resource_group.test.location
  size = "Standard_B1s"
  admin_username = "praveen"
  admin_password = "info1234!@#$A"
  disable_password_authentication = false
  network_interface_ids = [
    azurerm_network_interface.vmnic.id
  ]
  os_disk {
    name = "osdisk1"
    caching = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    publisher = "Canonical"
    offer = "UbuntuServer"
    sku = "16.04-LTS"
    version = "latest"
  }
  custom_data = filebase64("${path.module}/app-scripts/app1-cloud-init.txt")
  
 }


 
 resource "azurerm_linux_virtual_machine" "linuxvm2" {
  name = "mylinuxvm"
  computer_name = "devlinux-vm2"
  resource_group_name = azurerm_resource_group.test.name
  location = azurerm_resource_group.test.location
  size = "Standard_B1s"
  admin_username = "praveen"
  admin_password = "info1234!@#$A"
  disable_password_authentication = false
  network_interface_ids = [
    azurerm_network_interface.myvmnic2.id
  ] 
  os_disk {
    name = "osdisk2"
    caching = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    publisher = "Canonical"
    offer = "UbuntuServer"
    sku = "16.04-LTS"
    version = "latest"
  }
  custom_data = filebase64("${path.module}/app-scripts/app1-cloud-init.txt")
 }

# Create Load-Balancer Public IP

resource "azurerm_public_ip" "loadbalancerip" {
  depends_on = [
    azurerm_linux_virtual_machine.linuxvm
  ]
  name = "myloadbalancer-ip"
  sku = "Standard"
  resource_group_name = azurerm_resource_group.test.name
  location = azurerm_resource_group.test.location
  allocation_method = "Static"
}

# Create Load-Balancer 
resource "azurerm_lb" "loadbalancer" {
  depends_on = [
    azurerm_linux_virtual_machine.linuxvm2
    
  ]
  
  name = "loadbalancer"
  sku = "Standard"
  resource_group_name = azurerm_resource_group.test.name
  location = azurerm_resource_group.test.location
  frontend_ip_configuration {
    name = "myfrontendip"
    public_ip_address_id = azurerm_public_ip.loadbalancerip.id
  }
  
} 

# Create Health Probe

resource "azurerm_lb_probe" "probe" {
  name = "myprobe"
  loadbalancer_id = azurerm_lb.loadbalancer.id
  request_path = "/"
  port = 80
  protocol = "Http"
  interval_in_seconds = 5
}

 # Lb Back End Address Pool

resource "azurerm_lb_backend_address_pool" "addresspool" {
  name = "backendaddresspool"
  loadbalancer_id = azurerm_lb.loadbalancer.id  
}

# Create LB Rule

resource "azurerm_lb_rule" "lbrule" {
  loadbalancer_id = azurerm_lb.loadbalancer.id
  name = "mylbrule"
  protocol = "Tcp"
  frontend_port = 80
  backend_port = 80
  frontend_ip_configuration_name = "myfrontendip"
  probe_id = azurerm_lb_probe.probe.id
}

# Backend Pool Association
resource "azurerm_network_interface_backend_address_pool_association" "poolassociation" {
  network_interface_id = azurerm_network_interface.vmnic.id
  ip_configuration_name = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.addresspool.id
}

# Backend Pool Association2
resource "azurerm_network_interface_backend_address_pool_association" "myvmnic2" {
  network_interface_id = azurerm_network_interface.myvmnic2.id
  ip_configuration_name = "internal2"
  backend_address_pool_id = azurerm_lb_backend_address_pool.addresspool.id
}

# LB Nat Rule

resource "azurerm_lb_nat_rule" "ssh" {
  resource_group_name = azurerm_resource_group.test.name
  loadbalancer_id = azurerm_lb.loadbalancer.id
  name = "ssh1"
  protocol = "Tcp"
  frontend_port_start = 5000
  frontend_port_end = 5103
  backend_port = 22
  backend_address_pool_id = azurerm_lb_backend_address_pool.addresspool.id
  frontend_ip_configuration_name = "myfrontendip"

}
