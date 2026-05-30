
#VPC
resource "aws_vpc" "vpc" {
  cidr_block           = var.cidr_block
  instance_tenancy     = var.instance_tenancy
  enable_dns_support   = var.enable_dns_support
  enable_dns_hostnames = var.enable_dns_hostnames
  tags                 = merge({ Name = var.vpc_name }, var.tags)
}

resource "aws_subnet" "subnet" {
  for_each = var.subnets != {} ? var.subnets : {}

  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = lookup(each.value, "cidr_block", null)
  availability_zone       = lookup(each.value, "availability_zone", null)
  map_public_ip_on_launch = lookup(each.value, "map_public_ip_on_launch", false)
  tags                    = merge({ Name = "${each.key}" }, var.tags)
}

#igw
resource "aws_internet_gateway" "igw" {
  for_each = var.internet_gateway != null ? { for igw in [var.internet_gateway] : igw.name => igw } : {}
  vpc_id   = aws_vpc.vpc.id

  tags = merge({ Name = "${each.key}" }, var.tags)
}

#igw route
resource "aws_route" "igw_route" {
  for_each = var.internet_gateway != null ? { for igw in [var.internet_gateway] : igw.name => igw } : {}

  route_table_id         = aws_route_table.route_table[each.value.route_table_key].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw[each.key].id
}


#Elastic ip for natgateways
resource "aws_eip" "nat_eip" {
  for_each = {
    for k, v in var.nat_gateways : k => v
    if lookup(v, "connectivity_type", "public") == "public"
  }

  domain = "vpc"
  tags   = merge({ Name = "${each.key}-eip" }, var.tags)
}

resource "aws_nat_gateway" "ngw" {
  for_each = var.nat_gateways != null ? var.nat_gateways : {}

  subnet_id         = aws_subnet.subnet[each.value.subnet_key].id
  connectivity_type = lookup(each.value, "connectivity_type", "public")
  allocation_id     = lookup(each.value, "allocation_id", null) != null ? each.value.allocation_id : try(aws_eip.nat_eip[each.key].allocation_id, null)
  tags              = merge({ Name = "${each.key}" }, var.tags)

  depends_on = [aws_internet_gateway.igw]
}

resource "aws_route" "ngw_route" {
  for_each = var.nat_gateways != null ? var.nat_gateways : {}

  route_table_id         = aws_route_table.route_table[each.value.route_table_key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.ngw[each.key].id
}

resource "aws_route_table" "route_table" {
  for_each = { for rt_key, rt_value in var.route_tables : rt_key => rt_value }

  vpc_id = aws_vpc.vpc.id
  tags   = merge({ Name = "${each.key}" }, var.tags)
  dynamic "route" {
    for_each = lookup(each.value, "routes", [])
    content {
      cidr_block                = route.value.cidr_block
      gateway_id                = lookup(route.value, "gateway_id", null)
      nat_gateway_id            = lookup(route.value, "nat_gateway_id", null)
      network_interface_id      = lookup(route.value, "network_interface_id", null)
      transit_gateway_id        = lookup(route.value, "transit_gateway_id", null)
      vpc_peering_connection_id = lookup(route.value, "vpc_peering_connection_id", null)
    }
  }
}

resource "aws_route_table_association" "rt_subnet" {
  for_each = { for subnet_key, subnet_value in var.subnets : subnet_key => subnet_value if contains(keys(subnet_value), "route_table_key") }

  subnet_id      = aws_subnet.subnet[each.key].id
  route_table_id = aws_route_table.route_table[each.value.route_table_key].id
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
provider "aws" {
  region = var.aws_region
}