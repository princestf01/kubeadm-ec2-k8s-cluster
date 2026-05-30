
#Nodes
resource "aws_instance" "ec2" {
  for_each = var.nodes

  ami                         = lookup(each.value, "ami", null)
  instance_type               = lookup(each.value, "instance_type", "t3.medium")
  availability_zone           = lookup(each.value, "availability_zone", null)
  vpc_security_group_ids      = lookup(each.value, "attach_custom_network_interface", null) == null ? concat(coalesce(lookup(each.value, "vpc_security_group_ids", []), []), [for sg_key in coalesce(lookup(each.value, "security_group_keys", []), []) : aws_security_group.sg[sg_key].id]) : null
  subnet_id                   = lookup(each.value, "attach_custom_network_interface", null) == null ? lookup(each.value, "subnet_id", null) : null
  associate_public_ip_address = lookup(each.value, "attach_custom_network_interface", null) == null ? lookup(each.value, "associate_public_ip_address", false) : null
  iam_instance_profile        = lookup(each.value, "iam_instance_profile", null)
  key_name                    = lookup(each.value, "key_name", null)
  tenancy                     = lookup(each.value, "tenancy", null)
  user_data                   = lookup(each.value, "user_data", null)
  tags                        = merge({ Name = each.key }, lookup(each.value, "tags", {}))


  dynamic "primary_network_interface" {
    for_each = lookup(each.value, "attach_custom_network_interface", null) != null ? [each.value.attach_custom_network_interface] : []
    content {
      network_interface_id  = primary_network_interface.value.network_interface_id
      delete_on_termination = lookup(primary_network_interface.value, "delete_on_termination", false)
    }
  }

  dynamic "root_block_device" {
    for_each = lookup(each.value, "root_block_device", []) == null ? [] : [lookup(each.value, "root_block_device")]
    content {
      volume_type           = lookup(root_block_device.value, "volume_type", null)
      volume_size           = lookup(root_block_device.value, "volume_size", null)
      delete_on_termination = lookup(root_block_device.value, "delete_on_termination", null)
      iops                  = lookup(root_block_device.value, "iops", null)
      throughput            = lookup(root_block_device.value, "throughput", null)
    }
  }

  dynamic "ebs_block_device" {
    for_each = lookup(each.value, "ebs_block_devices", []) == null ? [] : each.value.ebs_block_devices
    content {
      device_name           = ebs_block_device.value.device_name
      volume_type           = lookup(ebs_block_device.value, "volume_type", null)
      volume_size           = lookup(ebs_block_device.value, "volume_size", null)
      delete_on_termination = lookup(ebs_block_device.value, "delete_on_termination", null)
      iops                  = lookup(ebs_block_device.value, "iops", null)
      throughput            = lookup(ebs_block_device.value, "throughput", null)
    }
  }
}


#security groups and rules
resource "aws_security_group" "sg" {
  for_each = var.security_groups

  name                   = each.value.name
  description            = each.value.description
  vpc_id                 = each.value.vpc_id
  revoke_rules_on_delete = lookup(each.value, "revoke_rules_on_delete", false)
  tags                   = merge({ Name = each.value.name }, lookup(each.value, "tags", {}))
}

locals {
  ingress_rules = merge([
    for sg_key, sg_value in var.security_groups : {
      for rule_key, rule in lookup(sg_value, "ingress", {}) : "${sg_key}_${rule_key}" => {
        sg_name                      = sg_key
        from_port                    = rule.from_port
        to_port                      = rule.to_port
        ip_protocol                  = lookup(rule, "ip_protocol", null)
        cidr_ipv4                    = lookup(rule, "cidr_ipv4", null)
        cidr_ipv6                    = lookup(rule, "cidr_ipv6", null)
        prefixed_list_id             = lookup(rule, "prefixed_list_id", null)
        referenced_security_group_id = lookup(rule, "referenced_security_group_id", null)
        sg_reference_key             = lookup(rule, "sg_reference_key", null)
        description                  = lookup(rule, "description", null)
      }
    }
  ]...)

}
resource "aws_vpc_security_group_ingress_rule" "ingress_rule" {
  for_each = local.ingress_rules

  security_group_id            = aws_security_group.sg[each.value.sg_name].id
  from_port                    = each.value.from_port
  to_port                      = each.value.to_port
  ip_protocol                  = each.value.ip_protocol
  cidr_ipv4                    = lookup(each.value, "cidr_ipv4", null)
  cidr_ipv6                    = lookup(each.value, "cidr_ipv6", null)
  prefix_list_id               = lookup(each.value, "prefixed_list_id", null)
  referenced_security_group_id = lookup(each.value, "referenced_security_group_id", null)
  description                  = lookup(each.value, "description", null)

}

locals {
  egress_rules = merge([
    for sg_key, sg_value in var.security_groups : {
      for rule_key, rule in lookup(sg_value, "egress", {}) : "${sg_key}_${rule_key}" => {
        sg_name                      = sg_key
        from_port                    = rule.from_port
        to_port                      = rule.to_port
        ip_protocol                  = lookup(rule, "ip_protocol", null)
        cidr_ipv4                    = lookup(rule, "cidr_ipv4", null)
        cidr_ipv6                    = lookup(rule, "cidr_ipv6", null)
        prefixed_list_id             = lookup(rule, "prefixed_list_id", null)
        referenced_security_group_id = lookup(rule, "referenced_security_group_id", null)
        description                  = lookup(rule, "description", null)
      }
    }
  ]...)
}

resource "aws_vpc_security_group_egress_rule" "egress_rule" {
  for_each = local.egress_rules

  security_group_id            = aws_security_group.sg[each.value.sg_name].id
  from_port                    = each.value.from_port
  to_port                      = each.value.to_port
  ip_protocol                  = each.value.ip_protocol
  cidr_ipv4                    = lookup(each.value, "cidr_ipv4", null)
  cidr_ipv6                    = lookup(each.value, "cidr_ipv6", null)
  prefix_list_id               = lookup(each.value, "prefixed_list_id", null)
  referenced_security_group_id = lookup(each.value, "referenced_security_group_id", null)
  description                  = lookup(each.value, "description", null)

}

terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.94.1"
    }
  }
}


