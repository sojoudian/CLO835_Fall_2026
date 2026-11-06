provider "aws" {
  region = "us-east-1"
}

# Latest Ubuntu 26.04 LTS (Resolute Raccoon), x86_64, from Canonical.
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

data "aws_subnet" "each" {
  for_each = toset(data.aws_subnets.default.ids)
  id       = each.value
}

# Not every zone offers every instance type. us-east-1e offers neither
# m5.large nor r5.large, so a fixed subnet choice can fail at launch.
data "aws_ec2_instance_type_offerings" "for_type" {
  location_type = "availability-zone"

  filter {
    name   = "instance-type"
    values = [local.instance_type]
  }
}

locals {
  # m5.large: 2 vCPU / 8 GB. The Learner Lab blocks xlarge and larger, and it
  # stops newer generations such as r6i a few seconds after launch.
  instance_type = "m5.large"

  good_zones = toset(data.aws_ec2_instance_type_offerings.for_type.locations)

  lab_subnet_id = sort([
    for s in data.aws_subnet.each : s.id
    if contains(local.good_zones, s.availability_zone)
  ])[0]
}

########################################################
# Security group
########################################################
resource "aws_security_group" "vm" {
  name        = "week03-docker-lab"
  description = "Week03 Docker networking, storage and security lab"
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
  description       = "Adminer web UI"
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
# Instance: ONE machine for the Week 03 Docker lab.
#
# bootstrap.sh installs Docker Engine and adds ubuntu to the docker group,
# because every step of this lab is a docker command.
########################################################
resource "aws_instance" "vm" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = local.instance_type
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
    Name = "week03-docker-lab"
  }
}

output "public_ip" {
  value = aws_instance.vm.public_ip
}

output "private_ip" {
  value = aws_instance.vm.private_ip
}

output "next_step" {
  value = "ssh -i <your-key.pem> ubuntu@${aws_instance.vm.public_ip}   # then follow localMachine.sh"
}

output "adminer_url" {
  value = "http://${aws_instance.vm.public_ip}:8080/"
}
