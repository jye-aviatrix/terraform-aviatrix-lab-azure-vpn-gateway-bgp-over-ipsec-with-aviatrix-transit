variable "resource_group_name" {
  type        = string
  description = "Provide Resource Group Name"
  default     = "lab-azure-vpn-gateway-bgp-over-ipsec-with-aviatrix-transit"
}

variable "region" {
  type        = string
  description = "Provide region of the resources"
  default     = "East US"
}

variable "tags" {
  type        = map(any)
  description = "Provide tags for resources"
  default = {
    Name = "lab-azure-vpn-gateway-bgp-over-ipsec-with-aviatrix-transit"
  }
}


variable "aviatrix_access_account" {
  type        = string
  description = "Provide Aviatrix Access Account name for the target Azure Subscription"
}

variable "aviatrix_transit_asn" {
  type = number
  description = "Provide ASN for Aviatrix Transit"
  default = 65001
}

variable "vng_name" {
  type = string
  description = "Provide VNG name"
  default = "vng"
}

variable "vng_asn" {
  type = number
  description = "Provide ASN for Azure VPN Gateway"
  default = 65010  
}