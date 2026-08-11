resource "oci_core_vcn" "main" {
  compartment_id = var.compartment_id
  display_name   = var.vcn_name
  cidr_blocks    = var.vcn_cidr_blocks
  dns_label      = coalesce(var.dns_label, replace(var.vcn_name, "-", ""))

  freeform_tags = var.tags
}

resource "oci_core_subnet" "main" {
  for_each = var.subnets

  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.main.id
  display_name   = each.key
  cidr_block     = each.value.cidr_block
  dns_label      = coalesce(each.value.dns_label, replace(each.key, "-", ""))

  freeform_tags = var.tags
}

resource "oci_core_internet_gateway" "main" {
  count = var.create_internet_gateway ? 1 : 0

  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.vcn_name}-igw"
  enabled        = true

  freeform_tags = var.tags
}

resource "oci_core_route_table" "public" {
  count = var.create_internet_gateway ? 1 : 0

  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.vcn_name}-public-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.main[0].id
  }

  freeform_tags = var.tags
}

resource "oci_core_route_table_attachment" "public" {
  for_each = { for k, v in var.subnets : k => v if v.is_public }

  subnet_id      = oci_core_subnet.main[each.key].id
  route_table_id = oci_core_route_table.public[0].id
}
