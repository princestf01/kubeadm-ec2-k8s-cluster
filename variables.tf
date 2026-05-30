variable "aws_region" {
  description = "The AWS region where the Kubernetes cluster will be deployed."
  type        = string
  default     = "ap-southeast-1"

}

variable "nodes" {
  description = "Nodes configuration for the Kubernetes cluster."
  type = map(object({
    ami                              = optional(string)
    instance_type                    = optional(string)
    availability_zone                = optional(string)
    vpc_security_group_ids           = optional(list(string))
    security_group_keys              = optional(list(string))
    subnet_id                        = optional(string)
    create_elastic_network_interface = optional(bool)
    associate_public_ip_address      = optional(bool)
    iam_instance_profile             = optional(string)
    key_name                         = optional(string)
    tenancy                          = optional(string)
    user_data                        = optional(string)
    tags                             = optional(map(string))
    attach_custom_network_interface = optional(object({ #Whether to attach a custom ENI created outside this module.
      network_interface_id  = string
      delete_on_termination = optional(bool)
    }), null)

    root_block_device = optional(object({
      volume_type           = optional(string)
      volume_size           = optional(number)
      delete_on_termination = optional(bool)
      iops                  = optional(number)
      throughput            = optional(number)
    }), null)
    ebs_block_devices = optional(list(object({
      device_name           = string
      volume_type           = optional(string)
      volume_size           = optional(number)
      delete_on_termination = optional(bool)
      iops                  = optional(number)
      throughput            = optional(number)
    })), null)
  }))
  default = {}
}


variable "security_groups" {
  description = "Security groups configuration."
  type = map(object({
    name                   = string
    description            = string
    vpc_id                 = string
    revoke_rules_on_delete = optional(bool)
    ingress = optional(map(object({
      from_port                    = number
      to_port                      = number
      ip_protocol                  = optional(any)
      cidr_ipv4                    = optional(string)
      cidr_ipv6                    = optional(string)
      prefixed_list_id             = optional(string)
      referenced_security_group_id = optional(string)
      sg_reference_key             = optional(string)
      description                  = optional(string)
    })), {})
    egress = optional(map(object({
      from_port                    = number
      to_port                      = number
      ip_protocol                  = optional(any)
      cidr_ipv4                    = optional(string)
      cidr_ipv6                    = optional(string)
      prefixed_list_id             = optional(string)
      referenced_security_group_id = optional(string)
      description                  = optional(string)
    })), {})
    tags = optional(map(string))
  }))
  default = {}
}

variable "tags" {
  description = "A map of tags to assign to resources."
  type        = map(string)
  default     = { stackid = "tf-kubeadm-cluster" }

}