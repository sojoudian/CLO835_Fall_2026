provider "aws" {
  region = "us-east-1"
}

# Latest Ubuntu 26.04 LTS (Resolute Raccoon), x86_64, from Canonical.
# 26.04 on purpose: the Dockerfile of the app starts with FROM ubuntu:26.04,
# so every manual command below matches one Dockerfile line. Ships Python 3.14.
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd*/ubuntu-resolute-26.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Default VPC + one subnet. The Learner Lab does not permit a new VPC.
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

locals {
  lab_subnet_id = sort(data.aws_subnets.default.ids)[0]
}

########################################################
# Security group
########################################################
resource "aws_security_group" "vm" {
  name        = "week02-manual-vm"
  description = "Week02 manual deployment VM"
  vpc_id      = data.aws_vpc.default.id
}

resource "aws_security_group_rule" "ssh" {
  type              = "ingress"
  security_group_id = aws_security_group.vm.id
  description       = "SSH"
  protocol          = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "app_manual" {
  type              = "ingress"
  security_group_id = aws_security_group.vm.id
  description       = "Flask app"
  protocol          = "tcp"
  from_port         = 8080
  to_port           = 8080
  cidr_blocks       = ["0.0.0.0/0"]
}


resource "aws_security_group_rule" "egress" {
  type              = "egress"
  security_group_id = aws_security_group.vm.id
  protocol          = "-1"
  from_port         = 0
  to_port           = 0
  cidr_blocks       = ["0.0.0.0/0"]
}

########################################################
# Instance: ONE machine for the manual deployment.
#
# bootstrap.sh installs git and NOTHING else. No Docker, no pip, no Flask.
# The student installs those by hand, and counts the steps. That is the lesson:
# the same steps appear inside the Dockerfile, and one build repeats them all.
########################################################
resource "aws_instance" "vm" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "r5.large" # 2 vCPU / 16 GB (the Learner Lab blocks xlarge and larger, and newer generations such as r6i)
  key_name               = var.key_name
  subnet_id              = local.lab_subnet_id
  vpc_security_group_ids = [aws_security_group.vm.id]
  iam_instance_profile   = var.lab_instance_profile

  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  user_data = file("${path.module}/bootstrap.sh")

  tags = {
    Name = "week02-manual-vm"
  }
}

output "public_ip" {
  value = aws_instance.vm.public_ip
}

output "private_ip" {
  value = aws_instance.vm.private_ip
}

output "next_step" {
  value = "ssh -i <your-key.pem> ubuntu@${aws_instance.vm.public_ip}   # then follow runAWS_EC2.sh"
}

output "app_url" {
  value = "http://${aws_instance.vm.public_ip}:8080/"
}
