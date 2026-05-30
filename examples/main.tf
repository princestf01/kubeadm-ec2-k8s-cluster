
terraform {
  backend "local" {
    path = "kubeadm.tfstate"
  }
}
#Network Resources
locals {
  # Combine into kubeadm token format
  kubeadm_token = "${random_string.kubeadm_token_id.result}.${random_string.kubeadm_token_secret.result}"
  tags = {
    gh_account = "princestf01"
    email      = "" 
  }
}
module "vpc" {
  source = "../modules/network"

  vpc_name   = "kadm-vpc"
  cidr_block = "10.0.0.0/20"
  aws_region = var.aws_region

  subnets = {
    public-snet-az1 = {
      cidr_block              = "10.0.8.0/27"
      availability_zone       = "${var.aws_region}a"
      map_public_ip_on_launch = true
      route_table_key         = "public-rt"
    },
    private-snet-az2 = {
      cidr_block              = "10.0.8.64/27"
      availability_zone       = "${var.aws_region}b"
      map_public_ip_on_launch = false
      route_table_key         = "private-rt"
    }
  }
  route_tables = {
    public-rt = {
      routes = []
      tags   = { Type = "public" }
    },
    private-rt = {
      routes = []
      tags   = { Type = "private" }
    }
  }

  nat_gateways = {
    kadm-natgw01 = {
      subnet_key        = "public-snet-az1"
      route_table_key   = "private-rt"
      connectivity_type = "public"
    }
  }
  internet_gateway = {
    name            = "kadm-igw"
    route_table_key = "public-rt"
  }
  tags = local.tags
}
# Generate the token ID (6 chars)
resource "random_string" "kubeadm_token_id" {
  length  = 6
  upper   = false
  numeric = true
  special = false
}

# Generate the token secret (16 chars)
resource "random_string" "kubeadm_token_secret" {
  length  = 16
  upper   = false
  numeric = true
  special = false
}

resource "aws_network_interface" "eni" {
  for_each = var.eni

  subnet_id       = module.vpc.subnet_ids[each.value.subnet_key]
  private_ips     = lookup(each.value, "private_ips", null)
  security_groups = [for sg_key in lookup(each.value, "security_group_keys", []) : module.nodes.security_group_ids[sg_key]]
  description     = lookup(each.value, "description", null)
  tags            = merge({ Name = "${each.key}-eni" }, lookup(each.value, "tags", {}))

}

module "nodes" {
  source = "./.."

  nodes = {
    controlplane = {
      ami           = data.aws_ami.ubuntu.id
      key_name      = data.aws_key_pair.kube_key_pair.key_name
      instance_type = "t3.medium"
      # subnet_id                        = module.vpc.subnet_ids["private-snet-az2"]
      # security_group_keys              = ["controlplane_sg", "weavenet_sg"]
      attach_custom_network_interface = {
        network_interface_id = aws_network_interface.eni["controlplane"].id
        # delete_on_termination = true
      }
      user_data = templatefile("${path.root}/../templates/user_data.tftpl", {
        node     = "master",
        hostname = "controlplane",
        master_private_ip = length(coalesce(aws_network_interface.eni["controlplane"].private_ips, [])) > 0 ? tolist(aws_network_interface.eni["controlplane"].private_ips)[0] : "",
        token             = local.kubeadm_token,
        cidr              = var.pod_network_cidr
      })

      tags = local.tags
    },

    workernode01 = {
      ami           = data.aws_ami.ubuntu.id
      key_name      = data.aws_key_pair.kube_key_pair.key_name
      instance_type = "t3.small"
      attach_custom_network_interface = {
        network_interface_id = aws_network_interface.eni["workernode01"].id
      }
      user_data = templatefile("${path.root}/../templates/user_data.tftpl", {
        node = "worker",
        hostname = "workernode01",
        master_private_ip = length(coalesce(aws_network_interface.eni["controlplane"].private_ips, [])) > 0 ? tolist(aws_network_interface.eni["controlplane"].private_ips)[0] : "",
        token = local.kubeadm_token,
        cidr = null
      })

      tags = local.tags
    },

    workernode02 = {
      ami           = data.aws_ami.ubuntu.id
      key_name      = data.aws_key_pair.kube_key_pair.key_name
      instance_type = "t3.small"
      attach_custom_network_interface = {
        network_interface_id = aws_network_interface.eni["workernode02"].id
      }
        user_data  = templatefile("${path.root}/../templates/user_data.tftpl", {
        node = "worker",
        hostname = "workernode02",
        master_private_ip = length(coalesce(aws_network_interface.eni["controlplane"].private_ips, [])) > 0 ? tolist(aws_network_interface.eni["controlplane"].private_ips)[0] : "",
        token = local.kubeadm_token,
        cidr = null
      })
      tags = local.tags
    },

    studentnode = {
      ami                         = data.aws_ami.ubuntu.id
      key_name                    = data.aws_key_pair.kube_key_pair.key_name
      instance_type               = "t3.small"
      subnet_id                   = module.vpc.subnet_ids["public-snet-az1"]
      security_group_keys         = ["ingress_vpc", "egress_internet", "studentnode_sg"]
      associate_public_ip_address = true

      tags = local.tags
    }
  }

  security_groups = {
    ingress_vpc = {
      name        = "ingress-vpc-sg"
      description = "Allow all inbound traffic from within the VPC"
      vpc_id      = module.vpc.vpc_id
      ingress = {
        "1" = { from_port = -1, to_port = -1, ip_protocol = "-1", cidr_ipv4 = module.vpc.vpc_cidr_block }

      }
    },

    egress_internet = {
      name        = "egress-internet-sg"
      description = "Allow all outbound traffic to the internet"
      vpc_id      = module.vpc.vpc_id
      ingress     = {}
      egress = {
        "1" = { from_port = -1, to_port = -1, ip_protocol = "-1", cidr_ipv4 = "0.0.0.0/0" }
      }
    },

    studentnode_sg = {
      name        = "studentnode-sg"
      description = "Security group for student nodes"
      vpc_id      = module.vpc.vpc_id
      ingress = {
        "1" = { from_port = 22, to_port = 22, ip_protocol = "tcp", cidr_ipv4 = data.localos_public_ip.my_ip.cidr }
        "2" = { from_port = 22, to_port = 22, ip_protocol = "tcp", cidr_ipv4 = "" } 
      }
      egress = {
        "1" = { from_port = 22, to_port = 22, ip_protocol = "tcp", cidr_ipv4 = module.vpc.vpc_cidr_block }
      }
    },

    controlplane_sg = {
      name        = "controlplane-sg"
      description = "Security group for control plane nodes"
      vpc_id      = module.vpc.vpc_id
      ingress = {
        "1" = { from_port = 22, to_port = 22, ip_protocol = "tcp", cidr_ipv4 = module.vpc.subnet_cidrs["public-snet-az1"] },
        "2" = { from_port = 6443, to_port = 6443, ip_protocol = "tcp", cidr_ipv4 = module.vpc.vpc_cidr_block, description = "Allow K8s API server access anyware inside the VPC" },
        "3" = { from_port = 2379, to_port = 2380, ip_protocol = "tcp", cidr_ipv4 = module.vpc.vpc_cidr_block, description = "Allow etcd server access anyware inside the VPC" }
      }
      egress = {}
    },

    workernode_sg = {
      name        = "workernode-sg"
      description = "Security group for worker nodes"
      vpc_id      = module.vpc.vpc_id
      ingress = {
        "1" = { from_port = 22, to_port = 22, ip_protocol = "tcp", cidr_ipv4 = module.vpc.subnet_cidrs["public-snet-az1"] },
        "2" = { from_port = 10250, to_port = 10250, ip_protocol = "tcp", cidr_ipv4 = module.vpc.subnet_cidrs["private-snet-az2"], description = "Allow K8s kubelet access anyware inside the VPC" },
        "3" = { from_port = 30000, to_port = 32767, ip_protocol = "tcp", cidr_ipv4 = "0.0.0.0/0", description = "Allow NodePort services access anyware inside the VPC" }
      }
      egress = {}
    },

    weavenet_sg = {
      name        = "weavenet-sg"
      description = "Security group for Weave Net"
      vpc_id      = module.vpc.vpc_id
      ingress = {
        "1" = { from_port = 6783, to_port = 6783, ip_protocol = "tcp", cidr_ipv4 = module.vpc.subnet_cidrs["private-snet-az2"], description = "Weave Net TCP" },
        "2" = { from_port = 6783, to_port = 6784, ip_protocol = "udp", cidr_ipv4 = module.vpc.subnet_cidrs["private-snet-az2"], description = "Weave Net UDP" },

      }
      egress = {}
    }
  }
  depends_on = [module.vpc]
}


terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.94.1"
    }
    localos = {
      source  = "fireflycons/localos"
      version = "0.2.1"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.7.2"
    }
  }
}
provider "aws" {
  region                      = var.aws_region
  skip_metadata_api_check     = true
  skip_region_validation      = true
  skip_credentials_validation = true

  default_tags {
    tags = {
      project = "kubeadm-k8s-cluster"
    }
  }
}
provider "localos" {
  # Configuration options
}
provider "random" {
  # Configuration options
}
