# Input Variables
variable "aws_region" {
  description = "Region in which AWS Resources to be created"
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
#--------------------------------------------------------------
#VPC Variables
#----------------------------------------------------------------
variable "vpc_name" {
  description = "VPC Name"
  type        = string
  default     = "webapp-vpc"
}

variable "cidr_block" {
  description = "VPC CIDR Block"
  type        = string
}

variable "instance_tenancy" {
  description = "VPC Instance Tenancy"
  type        = string
  default     = "default"

}
variable "enable_dns_support" {
  description = "Enable DNS Support in VPC"
  type        = bool
  default     = true
}
variable "enable_dns_hostnames" {
  description = "Enable DNS Hostnames in VPC"
  type        = bool
  default     = true
}

variable "internet_gateway" {
  description = "Create internet gateway and route"
  type = object({
    name            = string
    route_table_key = optional(string)
  })
  default = null
}

variable "nat_gateways" {
  description = "Map of NAT Gateways"
  type = map(object({
    subnet_key        = string
    allocation_id     = optional(string)
    connectivity_type = optional(string)
    route_table_key   = optional(string)
  }))
  default = null
}

variable "subnets" {
  description = "Maps of subnets to create"
  type = map(object({
    cidr_block              = optional(string)
    availability_zone       = optional(string)
    map_public_ip_on_launch = optional(bool)
    route_table_key         = optional(string)
  }))
  default = {}
}

variable "route_tables" {
  description = "Route Tables configuration."
  type = map(object({
    routes = optional(list(object({
      cidr_block                = optional(string)
      gateway_id                = optional(string) #internet gateway id
      nat_gateway_id            = optional(string)
      network_interface_id      = optional(string)
      transit_gateway_id        = optional(string)
      vpc_peering_connection_id = optional(string)
    })), [])
    tags = optional(map(string))
  }))
  default = {}
}