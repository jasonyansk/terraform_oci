output "instance_ids" {
  description = "Map of instance names to their OCIDs."
  value       = { for name, mod in module.instance : name => mod.instance_id }
}

output "instance_private_ips" {
  description = "Map of instance names to their private IP addresses."
  value       = { for name, mod in module.instance : name => mod.private_ip }
}

output "instance_public_ips" {
  description = "Map of instance names to their public IP addresses (if assigned)."
  value       = { for name, mod in module.instance : name => mod.public_ip }
}

output "instance_states" {
  description = "Map of instance names to their current states."
  value       = { for name, mod in module.instance : name => mod.instance_state }
}

output "boot_volume_ids" {
  description = "Map of instance names to their boot volume OCIDs."
  value       = { for name, mod in module.instance : name => mod.boot_volume_id }
}

output "all_instances" {
  description = "Complete map of all instance details."
  value = {
    for name, mod in module.instance : name => {
      id             = mod.instance_id
      name           = mod.instance_name
      private_ip     = mod.private_ip
      public_ip      = mod.public_ip
      state          = mod.instance_state
      boot_volume_id = mod.boot_volume_id
    }
  }
}
