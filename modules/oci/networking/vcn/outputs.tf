output "vcn_id" {
  description = "The OCID of the created VCN."
  value       = oci_core_vcn.main.id
}

output "vcn_cidr_blocks" {
  description = "The CIDR blocks of the VCN."
  value       = oci_core_vcn.main.cidr_blocks
}

output "subnet_ids" {
  description = "A map of subnet names to their OCIDs."
  value       = { for k, v in oci_core_subnet.main : k => v.id }
}

output "internet_gateway_id" {
  description = "The OCID of the Internet Gateway (if created)."
  value       = var.create_internet_gateway ? oci_core_internet_gateway.main[0].id : null
}

output "public_route_table_id" {
  description = "The OCID of the public route table (if created)."
  value       = var.create_internet_gateway ? oci_core_route_table.public[0].id : null
}
