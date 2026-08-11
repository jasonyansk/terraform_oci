output "vcn_id" {
  description = "The OCID of the VCN."
  value       = module.vcn.vcn_id
}

output "vcn_cidr_blocks" {
  description = "The CIDR blocks of the VCN."
  value       = module.vcn.vcn_cidr_blocks
}

output "subnet_ids" {
  description = "Map of subnet names to their OCIDs."
  value       = module.vcn.subnet_ids
}

output "nsg_ids" {
  description = "Map of NSG names to their OCIDs."
  value       = { for name, mod in module.nsg : name => mod.nsg_id }
}

output "app_subnet_nsg_id" {
  description = "The OCID of the app tier NSG."
  value       = module.nsg["app_subnet"].nsg_id
}

output "internet_gateway_id" {
  description = "The OCID of the Internet Gateway."
  value       = module.vcn.internet_gateway_id
}
