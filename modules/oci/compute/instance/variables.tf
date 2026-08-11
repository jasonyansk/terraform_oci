variable "compartment_id" {
  description = "The OCID of the compartment where the instance will be created."
  type        = string
}

variable "availability_domain" {
  description = "The availability domain for the instance."
  type        = string
}

variable "fault_domain" {
  description = "The fault domain for the instance."
  type        = string
  default     = null
}

variable "instance_name" {
  description = "The display name for the compute instance."
  type        = string
}

variable "shape" {
  description = "The shape of the instance (e.g., VM.Standard.A1.Flex)."
  type        = string
}

variable "shape_config" {
  description = "Configuration for flexible shapes (ocpus and memory)."
  type = object({
    ocpus         = number
    memory_in_gbs = number
  })
  default = null
}

variable "subnet_id" {
  description = "The OCID of the subnet where the instance will be created."
  type        = string
}

variable "source_image_id" {
  description = "The OCID of the image to use for the boot volume."
  type        = string
}

variable "assign_public_ip" {
  description = "Whether to assign a public IP address to the instance."
  type        = bool
  default     = false
}

variable "nsg_ids" {
  description = "List of NSG OCIDs to attach to the primary VNIC."
  type        = list(string)
  default     = []
}

variable "private_ip" {
  description = "A private IP address to assign to the instance."
  type        = string
  default     = null
}

variable "ssh_authorized_keys" {
  description = "SSH public key for Linux instances."
  type        = string
  default     = null
}

variable "os_type" {
  description = "Operating system type ('Linux' or 'Windows')."
  type        = string
  default     = "Linux"

  validation {
    condition     = contains(["Linux", "Windows"], var.os_type)
    error_message = "OS type must be either 'Linux' or 'Windows'."
  }
}

variable "user_data_base64" {
  description = "Base64-encoded user data (cloud-init) for the instance."
  type        = string
  default     = null
}

variable "boot_volume_size_in_gbs" {
  description = "Size of the boot volume in GB."
  type        = number
  default     = 50
}

variable "boot_volume_vpus_per_gb" {
  description = "VPUs per GB for the boot volume performance."
  type        = number
  default     = 10
}

variable "additional_volumes" {
  description = "Map of additional block volumes to attach."
  type = map(object({
    size_in_gbs     = number
    vpus_per_gb     = optional(number, 10)
    attachment_type = optional(string, "paravirtualized")
  }))
  default = {}
}

variable "agent_config" {
  description = "Configuration for OCI agents (monitoring and management)."
  type = object({
    is_management_disabled = optional(bool, false)
    is_monitoring_disabled = optional(bool, false)
  })
  default = {
    is_management_disabled = false
    is_monitoring_disabled = false
  }
}

variable "preserve_boot_volume" {
  description = "Whether to preserve the boot volume when the instance is terminated."
  type        = bool
  default     = false
}

variable "tags" {
  description = "A map of freeform tags to assign to the instance."
  type        = map(string)
  default     = {}
}
