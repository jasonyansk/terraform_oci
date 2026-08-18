# OCI Provider Authentication
variable "config_file_profile" {
  description = "The OCI config file profile to use for Security Token authentication."
  type        = string
  default     = "DEFAULT"
}

variable "region" {
  description = "The OCI region."
  type        = string
}

variable "compartment_id" {
  description = "The OCID of the compartment for app5 resources."
  type        = string
}

variable "availability_domain" {
  description = "The availability domain for compute instances."
  type        = string
}

variable "ssh_authorized_keys" {
  description = "SSH public key for instance access."
  type        = string
  default     = null
}

variable "source_image_id" {
  description = "Default OCID of the image used for instances that don't set their own instances[key].source_image_id. In this cluster that means the aarch64 image for the Ampere A1 nodes — the x86_64 AMD micro node overrides this per-instance."
  type        = string
}

variable "tags" {
  description = "Common tags for all resources."
  type        = map(string)
  default     = {}
}

# Optional override for platform infrastructure
variable "subnet_id" {
  description = "The OCID of the subnet. Defaults to platform appsubnet output if not provided."
  type        = string
  default     = null
}

variable "nsg_ids" {
  description = "List of NSG OCIDs. Defaults to platform app_subnet NSG if not provided."
  type        = list(string)
  default     = []
}

variable "instances" {
  description = "Map of instance definitions."
  type = map(object({
    shape            = string
    subnet_id        = optional(string, null)       # Optional: defaults to var.subnet_id or platform
    nsg_ids          = optional(list(string), null) # Optional: defaults to var.nsg_ids or platform
    assign_public_ip = optional(bool, false)
    fault_domain     = optional(string, null)
    ocpus            = optional(number, 1)
    memory_in_gbs    = optional(number, 4)
    boot_volume_size = optional(number, 50)
    private_ip       = optional(string, null)     # Static IP; control-plane needs this for --apiserver-advertise-address
    role             = optional(string, "worker") # "control-plane" or "worker" — drives the k8s cloud-init template
    source_image_id  = optional(string, null)     # Optional: defaults to var.source_image_id (aarch64). Set for x86_64 shapes.
    additional_tags  = optional(map(string), {})
  }))
}

# Kubernetes cluster bootstrap (kubeadm)
variable "kubernetes_version" {
  description = "Kubernetes minor version (major.minor, e.g. \"1.31\") to install from the pkgs.k8s.io apt repo. Check which version the CKA exam currently targets before bumping this."
  type        = string
  default     = "1.31"
}

variable "pod_network_cidr" {
  description = "Pod network CIDR passed to `kubeadm init` and matched by the Flannel CNI manifest."
  type        = string
  default     = "10.244.0.0/16"
}
