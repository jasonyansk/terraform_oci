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

  # Per-instance override, defaulting to var.source_image_id. Needed because the cluster now
  # mixes architectures: Ampere A1 nodes need an aarch64 image, the AMD Always Free micro
  # node needs an x86_64 one — see terraform.tfvars.
  source_image_ids = {
    for name, instance in var.instances : name => (
      instance.source_image_id != null ? instance.source_image_id : var.source_image_id
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
  private_ip              = each.value.private_ip
  fault_domain            = each.value.fault_domain
  source_image_id         = local.source_image_ids[each.key]
  ssh_authorized_keys     = var.ssh_authorized_keys
  boot_volume_size_in_gbs = each.value.boot_volume_size

  # Installs containerd + kubeadm/kubelet/kubectl on every node; additionally runs
  # `kubeadm init` + installs the Flannel CNI when role == "control-plane". See
  # templates/k8s-node-init.sh.tftpl and README.md for the manual `kubeadm join` step.
  user_data_base64 = base64encode(templatefile("${path.module}/templates/k8s-node-init.sh.tftpl", {
    is_control_plane   = each.value.role == "control-plane"
    node_name          = each.key
    private_ip         = each.value.private_ip
    pod_network_cidr   = var.pod_network_cidr
    kubernetes_version = var.kubernetes_version
  }))

  tags = merge(var.tags, each.value.additional_tags)
}