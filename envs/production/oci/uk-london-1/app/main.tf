# Read platform infrastructure state
data "terraform_remote_state" "platform" {
  backend = "local"

  config = {
    path = "../_platform/terraform.tfstate"
  }
}

locals {
  subnet_ids = {
    for name, instance in var.instances : name => (
      instance.subnet_id != null ? instance.subnet_id : (
        var.subnet_id != null ? var.subnet_id : data.terraform_remote_state.platform.outputs.subnet_ids["appsubnet"]
      )
    )
  }

  nsg_ids = {
    for name, instance in var.instances : name => (
      instance.nsg_ids != null ? instance.nsg_ids : (
        length(var.nsg_ids) > 0 ? var.nsg_ids : [data.terraform_remote_state.platform.outputs.nsg_ids["app_subnet"]]
      )
    )
  }
}

module "instance" {
  for_each = var.instances

  source = "../../../../../modules/oci/compute/instance"

  compartment_id      = var.compartment_id
  availability_domain = var.availability_domain
  instance_name       = each.key
  shape               = each.value.shape

  shape_config = each.value.shape != "VM.Standard.E2.1.Micro" ? {
    ocpus         = each.value.ocpus
    memory_in_gbs = each.value.memory_in_gbs
  } : null

  subnet_id               = local.subnet_ids[each.key]
  nsg_ids                 = local.nsg_ids[each.key]
  assign_public_ip        = each.value.assign_public_ip
  fault_domain            = each.value.fault_domain
  source_image_id         = var.source_image_id
  ssh_authorized_keys     = var.ssh_authorized_keys
  boot_volume_size_in_gbs = each.value.boot_volume_size

  tags = merge(var.tags, each.value.additional_tags)
}