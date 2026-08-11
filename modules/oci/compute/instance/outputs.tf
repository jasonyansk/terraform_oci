output "instance_id" {
  description = "The OCID of the created compute instance."
  value       = oci_core_instance.main.id
}

output "instance_name" {
  description = "The display name of the instance."
  value       = oci_core_instance.main.display_name
}

output "private_ip" {
  description = "The private IP address of the instance."
  value       = oci_core_instance.main.private_ip
}

output "public_ip" {
  description = "The public IP address of the instance (if assigned)."
  value       = oci_core_instance.main.public_ip
}

output "instance_state" {
  description = "The current state of the instance."
  value       = oci_core_instance.main.state
}

output "boot_volume_id" {
  description = "The OCID of the boot volume."
  value       = oci_core_instance.main.boot_volume_id
}

output "additional_volume_ids" {
  description = "A map of additional volume names to their OCIDs."
  value       = { for k, v in oci_core_volume.additional : k => v.id }
}
