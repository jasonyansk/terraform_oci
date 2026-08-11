variable "name" {
  description = "The display name for the Network Security Group."
  type        = string
}

variable "compartment_id" {
  description = "The OCID of the compartment where the NSG will be created."
  type        = string
}

variable "vcn_id" {
  description = "The OCID of the VCN where the NSG will be created."
  type        = string
}

variable "tags" {
  description = "A map of freeform tags to assign to the NSG."
  type        = map(string)
  default     = {}
}

variable "ingress_rules" {
  description = "List of ingress security rules."
  type = list(object({
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
  }))
  default = []
}

variable "egress_rules" {
  description = "List of egress security rules."
  type = list(object({
    protocol         = string
    destination      = string
    destination_type = string
    description      = optional(string, "")
    destination_port_range = optional(object({
      min = number
      max = number
    }), null)
  }))
  default = [
    {
      protocol         = "all"
      destination      = "0.0.0.0/0"
      destination_type = "CIDR_BLOCK"
      description      = "Allow all outbound traffic"
    }
  ]
}
