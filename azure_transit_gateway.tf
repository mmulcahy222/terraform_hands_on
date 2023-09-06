
# RESOURCE GROUP

resource "azurerm_resource_group" "resource_group_mark_mulcahy" {
  name     = var.resource_group_name
  location = var.location
}



# NETWORK SECURITY GROUPS

resource "azurerm_network_security_group" "security_group_mark" {
  name                = "security_group_mark"
  location            = var.location
  resource_group_name = var.resource_group_name
}

resource "azurerm_network_security_rule" "allow_ssh_rule" {
  name                        = "allow_ssh_rule"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "0.0.0.0/0" 
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.security_group_mark.name
}

resource "azurerm_network_security_rule" "allow_ping_rule" {
  name                        = "allow_ping_rule"
  priority                    = 101
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Icmp"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "0.0.0.0/0" 
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.security_group_mark.name
}


# VIRTUAL NETWORKS

resource "azurerm_virtual_network" "gateway_hub" {
  name                = "gateway_hub"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_virtual_network" "vpc_1" {
  name                = "vpc_1"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = ["10.1.0.0/16"]
}

resource "azurerm_virtual_network" "vpc_2" {
  name                = "vpc_2"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = ["10.2.0.0/16"]
}






# SUBNETS

resource "azurerm_subnet" "subnet_hub" {
  name                 = "subnet_hub"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.gateway_hub.name
  address_prefixes     = ["10.0.0.0/24"]
}

resource "azurerm_subnet" "subnet_1" {
  name                 = "subnet_1"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vpc_1.name
  address_prefixes     = ["10.1.0.0/24"]
}

resource "azurerm_subnet" "subnet_2" {
  name                 = "subnet_2"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vpc_2.name
  address_prefixes     = ["10.2.0.0/24"]
}

resource "azurerm_subnet" "subnet_hub_virtual_gateway" {
  name                 = "GatewaySubnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.gateway_hub.name
  address_prefixes     = ["10.0.1.0/24"]
}




# ROUTE TABLES

# VPC 1 / SUBNET 1 Route Table
resource "azurerm_route_table" "route_table_1" {
  name                = "route_table_1"
  location            = var.location
  resource_group_name = var.resource_group_name
}

resource "azurerm_route" "route_1" {
  name                = "route_1"
  resource_group_name = var.resource_group_name
  route_table_name    = azurerm_route_table.route_table_1.name
  address_prefix      = "10.2.0.0/16"
  next_hop_type       = "VirtualNetworkGateway"
}

resource "azurerm_subnet_route_table_association" "route_subnet_association_1" {
  subnet_id      = azurerm_subnet.subnet_1.id
  route_table_id = azurerm_route_table.route_table_1.id
}

# VPC 2 / SUBNET 2 Route Table
resource "azurerm_route_table" "route_table_2" {
  name                = "route_table_2"
  location            = var.location
  resource_group_name = var.resource_group_name
}

resource "azurerm_route" "route_2" {
  name                = "route_2"
  resource_group_name = var.resource_group_name
  route_table_name    = azurerm_route_table.route_table_2.name
  address_prefix      = "10.1.0.0/16"
  next_hop_type       = "VirtualNetworkGateway"
}

resource "azurerm_subnet_route_table_association" "route_subnet_association_2" {
  subnet_id      = azurerm_subnet.subnet_2.id
  route_table_id = azurerm_route_table.route_table_2.id
}










#########################
# 
#    VIRTUAL MACHINES
#
#
#
# Virtual Machine has a Network Interface
# Network Interface ID has a Public IP
# Public IP chooses location of this virtual machine
#
#

#########################
# 
#    VIRTUAL MACHINE IN HUB
#
#########################

##### PUBLIC IP #####
resource "azurerm_public_ip" "public_ip_hub" {
  name                = "public_ip_hub"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Dynamic"
}

##### NETWORK INTERFACE #####
resource "azurerm_network_interface" "network_interface_hub" {
  name                = "network_interface_hub"
  location            = var.location
  resource_group_name = var.resource_group_name
  ip_configuration {
    name                          = "ip_configuration"
    subnet_id                     = azurerm_subnet.subnet_hub.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip_hub.id
  }
}

##### NETWORK INTERFACE TO SECURITY GROUP ASSOCIATION #####
resource "azurerm_network_interface_security_group_association" "nsg_association_hub" {
  network_interface_id      = azurerm_network_interface.network_interface_hub.id
  network_security_group_id = azurerm_network_security_group.security_group_mark.id
}

##### SUBNET INTERFACE TO SECURITY GROUP ASSOCIATION ##### 
resource "azurerm_subnet_network_security_group_association" "ssh_nsg_to_vpc_hub" {
  subnet_id                 = azurerm_subnet.subnet_hub.id
  network_security_group_id = azurerm_network_security_group.security_group_mark.id
}


##### VIRTUAL MACHINE #####
#
# Virtual Machine has a Network Interface
# Network Interface ID has a Public IP
#
resource "azurerm_linux_virtual_machine" "virtual_machine_hub" {
  name                = "VMHub"
  location            = var.location
  resource_group_name = var.resource_group_name
  network_interface_ids = [
    azurerm_network_interface.network_interface_hub.id,
  ]
  size                            = "Standard_B1ls"
  admin_username                  = var.vm_username
  admin_password                  = var.vm_password 
  disable_password_authentication = false         
  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    name                 = "myosdisk"
  }
}







#########################
# 
#    VIRTUAL MACHINE IN SUBNET 1
#
#    
#
#########################


##### PUBLIC IP #####
resource "azurerm_public_ip" "public_ip_1" {
  name                = "public_ip_1"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Dynamic"
}

##### NETWORK INTERFACE #####
resource "azurerm_network_interface" "network_interface_1" {
  name                = "network_interface_1"
  location            = var.location
  resource_group_name = var.resource_group_name
  ip_configuration {
    name                          = "ip_configuration"
    subnet_id                     = azurerm_subnet.subnet_1.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip_1.id
  }
}

##### NETWORK INTERFACE TO SECURITY GROUP ASSOCIATION #####
resource "azurerm_network_interface_security_group_association" "nsg_association_1" {
  network_interface_id      = azurerm_network_interface.network_interface_1.id
  network_security_group_id = azurerm_network_security_group.security_group_mark.id
}

##### SUBNET INTERFACE TO SECURITY GROUP ASSOCIATION ##### 
resource "azurerm_subnet_network_security_group_association" "ssh_nsg_to_vpc_1" {
  subnet_id                 = azurerm_subnet.subnet_1.id
  network_security_group_id = azurerm_network_security_group.security_group_mark.id
}


##### VIRTUAL MACHINE #####
#
# Virtual Machine has a Network Interface
# Network Interface ID has a Public IP
#
resource "azurerm_linux_virtual_machine" "virtual_machine_1" {
  name                = "VMSubnet1"
  location            = var.location
  resource_group_name = var.resource_group_name
  network_interface_ids = [
    azurerm_network_interface.network_interface_1.id,
  ]
  size                            = "Standard_B1ls"
  admin_username                  = var.vm_username
  admin_password                  = var.vm_password
  disable_password_authentication = false         
  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    name                 = "myosdisk_subnet_1"
  }
}






#########################
# 
#    VIRTUAL MACHINE IN SUBNET 2
#
#    
#
#########################


##### PUBLIC IP #####
resource "azurerm_public_ip" "public_ip_2" {
  name                = "public_ip_2"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Dynamic"
}

##### NETWORK INTERFACE #####
resource "azurerm_network_interface" "network_interface_2" {
  name                = "network_interface_2"
  location            = var.location
  resource_group_name = var.resource_group_name
  ip_configuration {
    name                          = "ip_configuration"
    subnet_id                     = azurerm_subnet.subnet_2.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip_2.id
  }
}


#
#    Security group assignment to network Interface 
#
resource "azurerm_network_interface_security_group_association" "nsg_association_2" {
  network_interface_id      = azurerm_network_interface.network_interface_2.id
  network_security_group_id = azurerm_network_security_group.security_group_mark.id
}

#
#    Security group assignment to subnet
#
resource "azurerm_subnet_network_security_group_association" "ssh_nsg_to_vpc_2" {
  subnet_id                 = azurerm_subnet.subnet_2.id
  network_security_group_id = azurerm_network_security_group.security_group_mark.id
}


##### VIRTUAL MACHINE #####
#
# Virtual Machine has a Network Interface
# Network Interface ID has a Public IP
#
resource "azurerm_linux_virtual_machine" "virtual_machine_2" {
  name                = "VMSubnet2"
  location            = var.location
  resource_group_name = var.resource_group_name
  network_interface_ids = [
    azurerm_network_interface.network_interface_2.id,
  ]
  size                            = "Standard_B1ls"
  admin_username                  = var.vm_username
  admin_password                  = var.vm_password
  disable_password_authentication = false           
  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    name                 = "myosdisk_subnet_2"
  }
}













#########################
# 
#    VIRTUAL NETWORK GATEWAY
#
#########################

resource "azurerm_public_ip" "public_ip_hub_vnet_gateway" {
  name                = "public_ip_hub_vnet_gateway"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Dynamic"
}

resource "azurerm_virtual_network_gateway" "virtual_network_gateway" {
  name                = "virtual_network_gateway"
  location            = var.location
  resource_group_name = var.resource_group_name
  type     = "Vpn"
  vpn_type = "RouteBased"
  active_active = false
  enable_bgp    = false
  sku           = "VpnGw1"
  generation    = "Generation1"
  ip_configuration {
    name                          = "vnetGatewayConfig"
    public_ip_address_id          = azurerm_public_ip.public_ip_hub_vnet_gateway.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.subnet_hub_virtual_gateway.id
  }
}
















#########################
# 
#    VIRTUAL NETWORK PEERINGS
#
#    Requires two way peering, and two way peering is a requirement for the Virtual Network Gateway to work
#
#########################

resource "azurerm_virtual_network_peering" "vpc_1_to_hub" {
  name                      = "vpc1_to_hub"
  resource_group_name       = var.resource_group_name
  virtual_network_name      = azurerm_virtual_network.vpc_1.name
  remote_virtual_network_id = azurerm_virtual_network.gateway_hub.id
  allow_virtual_network_access = true
  allow_forwarded_traffic = true
  allow_gateway_transit   = true
  use_remote_gateways     = true
  depends_on = [azurerm_virtual_network.gateway_hub, azurerm_virtual_network.vpc_1, azurerm_virtual_network.vpc_2, azurerm_virtual_network_gateway.virtual_network_gateway]
}

resource "azurerm_virtual_network_peering" "vpc_2_to_hub" {
  name                      = "vpc2_to_hub"
  resource_group_name       = var.resource_group_name
  virtual_network_name      = azurerm_virtual_network.vpc_2.name
  remote_virtual_network_id = azurerm_virtual_network.gateway_hub.id
  allow_virtual_network_access = true
  allow_forwarded_traffic = true
  allow_gateway_transit   = true
  use_remote_gateways     = true
  depends_on = [azurerm_virtual_network.gateway_hub, azurerm_virtual_network.vpc_1, azurerm_virtual_network.vpc_2, azurerm_virtual_network_gateway.virtual_network_gateway]
}

resource "azurerm_virtual_network_peering" "hub_to_vpc_1" {
  name                      = "hub_to_vpc_1"
  resource_group_name       = var.resource_group_name
  virtual_network_name      = azurerm_virtual_network.gateway_hub.name
  remote_virtual_network_id = azurerm_virtual_network.vpc_1.id
  allow_virtual_network_access = true
  allow_forwarded_traffic = true
  allow_gateway_transit   = true
  depends_on = [azurerm_virtual_network.gateway_hub, azurerm_virtual_network.vpc_1, azurerm_virtual_network.vpc_2,azurerm_virtual_network_gateway.virtual_network_gateway]
}

resource "azurerm_virtual_network_peering" "hub_to_vpc_2" {
  name                      = "hub_to_vpc_2"
  resource_group_name       = var.resource_group_name
  virtual_network_name      = azurerm_virtual_network.gateway_hub.name
  remote_virtual_network_id = azurerm_virtual_network.vpc_2.id
  allow_virtual_network_access = true
  allow_forwarded_traffic = true
  allow_gateway_transit   = true
  depends_on = [azurerm_virtual_network.gateway_hub, azurerm_virtual_network.vpc_1, azurerm_virtual_network.vpc_2, azurerm_virtual_network_gateway.virtual_network_gateway]
}

