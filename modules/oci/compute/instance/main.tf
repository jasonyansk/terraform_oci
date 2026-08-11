locals {
  is_windows = var.os_type == "Windows"
}

resource "oci_core_instance" "main" {
  availability_domain = var.availability_domain
  compartment_id      = var.compartment_id
  display_name        = var.instance_name
  shape               = var.shape

  dynamic "shape_config" {
    for_each = var.shape_config != null ? [var.shape_config] : []
    content {
      ocpus         = shape_config.value.ocpus
      memory_in_gbs = shape_config.value.memory_in_gbs
    }
  }

  create_vnic_details {
    subnet_id        = var.subnet_id
    display_name     = "${var.instance_name}-vnic"
    assign_public_ip = var.assign_public_ip
    nsg_ids          = var.nsg_ids
    private_ip       = var.private_ip
    hostname_label   = var.instance_name
  }

  source_details {
    source_type             = "image"
    source_id               = var.source_image_id
    boot_volume_size_in_gbs = var.boot_volume_size_in_gbs
    boot_volume_vpus_per_gb = var.boot_volume_vpus_per_gb
  }

  metadata = {
    ssh_authorized_keys = local.is_windows ? null : var.ssh_authorized_keys
    user_data           = var.user_data_base64
  }

  agent_config {
    is_management_disabled = var.agent_config.is_management_disabled
    is_monitoring_disabled = var.agent_config.is_monitoring_disabled
  }

  dynamic "availability_config" {
    for_each = var.fault_domain != null ? [1] : []
    content {
      recovery_action = "RESTORE_INSTANCE"
    }
  }

  fault_domain = var.fault_domain

  freeform_tags = var.tags

  preserve_boot_volume = var.preserve_boot_volume
}

resource "oci_core_volume" "additional" {
  for_each = var.additional_volumes

  availability_domain = var.availability_domain
  compartment_id      = var.compartment_id
  display_name        = "${var.instance_name}-${each.key}"
  size_in_gbs         = each.value.size_in_gbs
  vpus_per_gb         = each.value.vpus_per_gb

  freeform_tags = var.tags
}

resource "oci_core_volume_attachment" "additional" {
  for_each = var.additional_volumes

  attachment_type = each.value.attachment_type
  instance_id     = oci_core_instance.main.id
  volume_id       = oci_core_volume.additional[each.key].id
}
