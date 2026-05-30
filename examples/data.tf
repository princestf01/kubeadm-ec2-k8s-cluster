#AMI reference for ubuntu
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
  region = var.aws_region
}

data "aws_key_pair" "kube_key_pair" {
  key_name = "tf-test-singapore"
  region   = var.aws_region

  filter {
    name   = "tag:region"
    values = ["${var.aws_region}"]
  }

}

data "localos_public_ip" "my_ip" {}
