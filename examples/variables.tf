variable "aws_region" {
  description = "Region in which AWS Resources to be created"
  type        = string
  default     = "ap-southeast-1"
}

variable "pod_network_cidr" {
  description = "Cluster pod network CIDR"
  type        = string
  default     = "10.244.0.0/16"
}
variable "eni" {
  description = "Custom ENI configuration"
  type = map(object({
    subnet_key          = string
    security_group_keys = optional(list(string))
    private_ips         = optional(list(string))
    description         = optional(string)
    tags                = optional(map(string))
  }))
  default = {}
}