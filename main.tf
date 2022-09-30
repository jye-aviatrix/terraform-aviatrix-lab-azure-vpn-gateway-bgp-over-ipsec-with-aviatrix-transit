# Reference for creating VPN Gateway for site to site connection
# https://learn.microsoft.com/en-us/azure/vpn-gateway/tutorial-site-to-site-portal


# Create parent Resource Group to house resources
resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.region
  tags     = var.tags
}

# Create Azure Router Server and Virtual VPN Gateway's vNet
resource "azurerm_virtual_network" "ars_vng" {
  name                = "vng-network"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = ["10.0.10.0/24"]
  tags                = var.tags

}

# Create Subnet for Virtual Private Gateway
resource "azurerm_subnet" "vng_subnet" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.ars_vng.name
  address_prefixes     = ["10.0.10.0/27"]
}

resource "azurerm_public_ip" "vng_pip_1" {
  name                = "vng-pip-1"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name

  allocation_method = "Dynamic"
}

resource "azurerm_public_ip" "vng_pip_2" {
  name                = "vng-pip-2"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name

  allocation_method = "Dynamic"
}

resource "azurerm_virtual_network_gateway" "this" {
  name                = var.vng_name
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name

  type     = "Vpn"
  vpn_type = "RouteBased"

  active_active = true
  enable_bgp    = true
  sku           = "VpnGw2"

  generation = "Generation2"

  bgp_settings {
    asn         = var.vng_asn
    peer_weight = 0

    peering_addresses {
    }
    peering_addresses {
    }
  }



  ip_configuration {
    name                          = "vnetGatewayConfig1"
    public_ip_address_id          = azurerm_public_ip.vng_pip_1.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.vng_subnet.id
  }

  ip_configuration {
    name                          = "vnetGatewayConfig2"
    public_ip_address_id          = azurerm_public_ip.vng_pip_2.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.vng_subnet.id
  }
}


module "mc-transit" {
  source          = "terraform-aviatrix-modules/mc-transit/aviatrix"
  version         = "2.2.1"
  cloud           = "azure"
  region          = var.region
  cidr            = "10.100.0.0/23"
  account         = var.aviatrix_access_account
  name            = "avx-transit"
  local_as_number = var.aviatrix_transit_asn
  resource_group  = azurerm_resource_group.this.name
}




resource "aviatrix_transit_external_device_conn" "this" {
  vpc_id            = module.mc-transit.transit_gateway.vpc_id
  connection_name   = "${module.mc-transit.transit_gateway.gw_name}-to-${var.vng_name}"
  gw_name           = module.mc-transit.transit_gateway.gw_name
  connection_type   = "bgp"
  tunnel_protocol   = "IPsec"
  enable_ikev2 = true
  custom_algorithms = true
  phase_1_authentication = "SHA-1"
  phase_1_dh_groups = 2
  phase_1_encryption = "AES-256-CBC"
  phase_2_authentication = "HMAC-SHA-1"
  phase_2_dh_groups = 2
  phase_2_encryption = "AES-256-CBC"
  bgp_local_as_num  = module.mc-transit.transit_gateway.local_as_number
  bgp_remote_as_num = azurerm_virtual_network_gateway.this.bgp_settings[index([for v in azurerm_virtual_network_gateway.this.bgp_settings : contains(flatten(v.peering_addresses[*].tunnel_ip_addresses), azurerm_public_ip.vng_pip_1.ip_address)], true)].asn
  remote_gateway_ip = join(",", flatten(azurerm_virtual_network_gateway.this.bgp_settings[*].peering_addresses[*].tunnel_ip_addresses))
}


resource "azurerm_local_network_gateway" "primary" {
  name                = module.mc-transit.transit_gateway.gw_name
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  gateway_address     = module.mc-transit.transit_gateway.public_ip
  bgp_settings {
    asn         = module.mc-transit.transit_gateway.local_as_number
    peer_weight = 0

    bgp_peering_address = module.mc-transit.transit_gateway.private_ip
  }
}

resource "azurerm_local_network_gateway" "ha" {
  name                = module.mc-transit.transit_gateway.ha_gw_name
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  gateway_address     = module.mc-transit.transit_gateway.ha_public_ip
  bgp_settings {
    asn         = module.mc-transit.transit_gateway.local_as_number
    peer_weight = 0

    bgp_peering_address = module.mc-transit.transit_gateway.ha_private_ip
  }
}

resource "azurerm_virtual_network_gateway_connection" "primary" {
  name                = module.mc-transit.transit_gateway.gw_name
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name

  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.this.id
  local_network_gateway_id   = azurerm_local_network_gateway.primary.id

  shared_key = aviatrix_transit_external_device_conn.this.pre_shared_key
}

resource "azurerm_virtual_network_gateway_connection" "ha" {
  name                = module.mc-transit.transit_gateway.ha_gw_name
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name

  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.this.id
  local_network_gateway_id   = azurerm_local_network_gateway.ha.id

  shared_key = aviatrix_transit_external_device_conn.this.backup_pre_shared_key
}
