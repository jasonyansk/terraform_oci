# VCN Module - Enterprise networking foundation
module "vcn" {
  source = "../../../../../modules/oci/networking/vcn" # Points to VCN in this context if structure allows, or explicit path

  compartment_id  = var.compartment_id
  vcn_name        = "vcn-${var.environment}-${var.region}"
  vcn_cidr_blocks = var.vcn_cidr_blocks
  dns_label       = var.dns_label

  subnets = {
    for name, cidr in var.subnet_cidrs : name => {
      cidr_block = cidr
      is_public  = contains(var.public_subnet_names, name)
    }
  }

  tags = merge(
    var.tags,
    {
      Component = "Networking"
      Tier      = "Platform"
    }
  )
}

# Network Security Groups - Dynamic creation based on configuration
module "nsg" {
  for_each = var.nsgs

  source = "../../../../../modules/oci/security/nsg"

  name           = "nsg-${each.key}-${var.environment}-${var.region}"
  compartment_id = var.compartment_id
  vcn_id         = module.vcn.vcn_id

  tags          = var.tags
  ingress_rules = each.value.ingress_rules
  egress_rules  = each.value.egress_rules
}
