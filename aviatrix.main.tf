module "mc-transit" {
  source          = "terraform-aviatrix-modules/mc-transit/aviatrix"
  version         = "2.5.3"
  cloud           = "azure"
  region          = var.region
  cidr            = "10.100.0.0/23"
  account         = var.aviatrix_access_account
  name            = "avx-transit"
  local_as_number = var.aviatrix_transit_asn
  resource_group  = azurerm_resource_group.this.name
  bgp_ecmp = true
}

# Create a spoke and attach to transit
module "mc-spoke" {
  source  = "terraform-aviatrix-modules/mc-spoke/aviatrix"
  version = "1.6.9"
  cloud           = "azure"
  region          = var.region
  cidr            = "10.200.0.0/23"
  account         = var.aviatrix_access_account
  name            = "avx-spoke"
  resource_group  = azurerm_resource_group.this.name
  transit_gw = module.mc-transit.transit_gateway.gw_name
}

resource "aviatrix_transit_external_device_conn" "this" {
  vpc_id            = module.mc-transit.transit_gateway.vpc_id
  connection_name   = "${module.mc-transit.transit_gateway.gw_name}-to-${var.vng_name}"
  gw_name           = module.mc-transit.transit_gateway.gw_name
  connection_type   = "bgp"
  tunnel_protocol   = "IPsec"
  enable_ikev2 = true
  bgp_local_as_num  = module.mc-transit.transit_gateway.local_as_number
  bgp_remote_as_num = var.vng_asn
  remote_gateway_ip = join(",", flatten(azurerm_virtual_network_gateway.this.bgp_settings[*].peering_addresses[*].tunnel_ip_addresses))
  local_tunnel_cidr = "${var.avx_primary_tunnel_ip}/30,${var.avx_ha_tunnel_ip}/30"
  remote_tunnel_cidr = "${var.vng_primary_tunnel_ip}/30,${var.vng_ha_tunnel_ip}/30"
  pre_shared_key = random_string.psk.result
}
