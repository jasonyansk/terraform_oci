variable "compartment_id" {
  description = "The OCID of the compartment where resources will be created."
  type        = string
}

variable "vcn_name" {
  description = "The display name for the Virtual Cloud Network (VCN)."
  type        = string
}

variable "vcn_cidr_blocks" {
  description = "List of CIDR blocks for the VCN."
  type        = list(string)
}

variable "dns_label" {
  description = "The DNS label for the VCN. Must be unique within the region."
  type        = string
  default     = null
}

variable "subnets" {
  description = "Map of subnet configurations."
  type = map(object({
    cidr_block = string
    is_public  = optional(bool, false)
    dns_label  = optional(string, null)
  }))
  default = {}
}

variable "create_internet_gateway" {
  description = "Whether to create an Internet Gateway and public route table."
  type        = bool
  default     = true
}

variable "tags" {
  description = "A map of freeform tags to assign to resources."
  type        = map(string)
  default     = {}
}
