output "nsg_id" {
  description = "The OCID of the created Network Security Group."
  value       = oci_core_network_security_group.main.id
}

output "nsg_name" {
  description = "The display name of the NSG."
  value       = oci_core_network_security_group.main.display_name
}
