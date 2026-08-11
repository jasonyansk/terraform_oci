# OCI Provider Authentication
variable "config_file_profile" {
  description = "The OCI config file profile to use for Security Token authentication."
  type        = string
  default     = "DEFAULT"
}

variable "compartment_id" {
  description = "The OCID of the compartment for platform resources."
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., development)."
  type        = string
}

variable "region" {
  description = "OCI region name."
  type        = string
}

variable "vcn_cidr_blocks" {
  description = "List of CIDR blocks for the VCN."
  type        = list(string)
}

variable "dns_label" {
  description = "DNS label for the VCN."
  type        = string
  default     = ""
}

variable "subnet_cidrs" {
  description = "Map of subnet names to CIDR blocks."
  type        = map(string)
}

variable "public_subnet_names" {
  description = "List of subnet names that require public internet access."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Common tags for all resources."
  type        = map(string)
  default     = {}
}

variable "nsgs" {
  description = "Map of NSG configurations. Key is the NSG name suffix."
  type = map(object({
    ingress_rules = optional(list(object({
      protocol    = string
      source      = string
      source_type = string
      description = optional(string, "")
      destination_port_range = optional(object({
        min = number
        max = number
      }), null)
      icmp_type = optional(object({
        type = number
        code = optional(number, null)
      }), null)
    })), [])
    egress_rules = optional(list(object({
      protocol         = string
      destination      = string
      destination_type = string
      description      = optional(string, "")
      destination_port_range = optional(object({
        min = number
        max = number
      }), null)
      })), [
      {
        protocol         = "all"
        destination      = "0.0.0.0/0"
        destination_type = "CIDR_BLOCK"
        description      = "Allow all outbound traffic"
      }
    ])
  }))
  default = {}
}
