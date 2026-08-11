resource "oci_core_network_security_group" "main" {
  compartment_id = var.compartment_id
  vcn_id         = var.vcn_id
  display_name   = var.name

  freeform_tags = var.tags
}

resource "oci_core_network_security_group_security_rule" "ingress" {
  for_each = { for idx, rule in var.ingress_rules : idx => rule }

  network_security_group_id = oci_core_network_security_group.main.id
  direction                 = "INGRESS"
  protocol                  = each.value.protocol
  description               = each.value.description
  source                    = each.value.source
  source_type               = each.value.source_type

  dynamic "tcp_options" {
    for_each = each.value.protocol == "6" && each.value.destination_port_range != null ? [each.value.destination_port_range] : []
    content {
      destination_port_range {
        min = tcp_options.value.min
        max = tcp_options.value.max
      }
    }
  }

  dynamic "icmp_options" {
    for_each = each.value.protocol == "1" && each.value.icmp_type != null ? [each.value.icmp_type] : []
    content {
      type = icmp_options.value.type
      code = icmp_options.value.code
    }
  }
}

resource "oci_core_network_security_group_security_rule" "egress" {
  for_each = { for idx, rule in var.egress_rules : idx => rule }

  network_security_group_id = oci_core_network_security_group.main.id
  direction                 = "EGRESS"
  protocol                  = each.value.protocol
  description               = each.value.description
  destination               = each.value.destination
  destination_type          = each.value.destination_type

  dynamic "tcp_options" {
    for_each = each.value.protocol == "6" && each.value.destination_port_range != null ? [each.value.destination_port_range] : []
    content {
      destination_port_range {
        min = tcp_options.value.min
        max = tcp_options.value.max
      }
    }
  }
}
