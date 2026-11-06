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

# Default VPC. The Learner Lab does not permit a new VPC.
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

# Not every zone offers every instance type. us-east-1e offers no m5.large.
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

  # All three nodes share ONE subnet and ONE availability zone. kubeadm and
  # Flannel expect flat, low-latency connectivity between the nodes.
  good_zones = toset(data.aws_ec2_instance_type_offerings.for_type.locations)
  lab_subnet_id = sort([
    for s in data.aws_subnet.each : s.id
    if contains(local.good_zones, s.availability_zone)
  ])[0]

  # kubeadm bootstrap token, shared by the master (--token) and the workers
  # (--token). The workers join without copying anything from the master.
  # Format: 6 chars "." 16 chars, lowercase letters and digits. Lab only.
  k8s_token = "week05.0123456789abcdef"
}

########################################################
# Security groups
########################################################
resource "aws_security_group" "master" {
  name        = "week05-k8s-master"
  description = "Week05 Kubernetes control-plane node"
  vpc_id      = data.aws_vpc.default.id
}

resource "aws_security_group" "worker" {
  name        = "week05-k8s-worker"
  description = "Week05 Kubernetes worker nodes"
  vpc_id      = data.aws_vpc.default.id
}

# --- Node to node: allow ALL traffic between the cluster nodes ---
# This covers every component port without listing each one:
#   etcd 2379-2380, kubelet 10250, kube-scheduler 10259,
#   kube-controller-manager 10257, kube-proxy 10256,
#   API 6443 node to node, Flannel VXLAN 8472/UDP.
resource "aws_security_group_rule" "master_from_self" {
  type              = "ingress"
  security_group_id = aws_security_group.master.id
  self              = true
  protocol          = "-1"
  from_port         = 0
  to_port           = 0
}

resource "aws_security_group_rule" "master_from_worker" {
  type                     = "ingress"
  security_group_id        = aws_security_group.master.id
  source_security_group_id = aws_security_group.worker.id
  protocol                 = "-1"
  from_port                = 0
  to_port                  = 0
}

resource "aws_security_group_rule" "worker_from_self" {
  type              = "ingress"
  security_group_id = aws_security_group.worker.id
  self              = true
  protocol          = "-1"
  from_port         = 0
  to_port           = 0
}

resource "aws_security_group_rule" "worker_from_master" {
  type                     = "ingress"
  security_group_id        = aws_security_group.worker.id
  source_security_group_id = aws_security_group.master.id
  protocol                 = "-1"
  from_port                = 0
  to_port                  = 0
}

# --- From the internet ---
resource "aws_security_group_rule" "master_ssh" {
  type              = "ingress"
  security_group_id = aws_security_group.master.id
  description       = "SSH"
  protocol          = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "master_api" {
  type              = "ingress"
  security_group_id = aws_security_group.master.id
  description       = "Kubernetes API server"
  protocol          = "tcp"
  from_port         = 6443
  to_port           = 6443
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "worker_ssh" {
  type              = "ingress"
  security_group_id = aws_security_group.worker.id
  description       = "SSH"
  protocol          = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_blocks       = ["0.0.0.0/0"]
}

# A NodePort Service opens its port on EVERY node, so open the range on both.
resource "aws_security_group_rule" "master_nodeport" {
  type              = "ingress"
  security_group_id = aws_security_group.master.id
  description       = "NodePort Services"
  protocol          = "tcp"
  from_port         = 30000
  to_port           = 32767
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "worker_nodeport" {
  type              = "ingress"
  security_group_id = aws_security_group.worker.id
  description       = "NodePort Services"
  protocol          = "tcp"
  from_port         = 30000
  to_port           = 32767
  cidr_blocks       = ["0.0.0.0/0"]
}

# --- Egress: allow all, on both ---
resource "aws_security_group_rule" "master_egress" {
  type              = "egress"
  security_group_id = aws_security_group.master.id
  protocol          = "-1"
  from_port         = 0
  to_port           = 0
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "worker_egress" {
  type              = "egress"
  security_group_id = aws_security_group.worker.id
  protocol          = "-1"
  from_port         = 0
  to_port           = 0
  cidr_blocks       = ["0.0.0.0/0"]
}

########################################################
# Instances: 1 master + 2 workers.
#
# The cluster forms itself at boot. bootstrap.sh installs the kubeadm
# prerequisites on every node. The master then runs kubeadm init and installs
# Flannel. Each worker retries kubeadm join until the API answers.
########################################################
resource "aws_instance" "master" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = local.instance_type
  key_name               = var.key_name
  subnet_id              = local.lab_subnet_id
  vpc_security_group_ids = [aws_security_group.master.id]
  iam_instance_profile   = var.lab_instance_profile

  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  user_data = "${file("${path.module}/bootstrap.sh")}\n${templatefile("${path.module}/master-init.sh.tftpl", {
    k8s_token = local.k8s_token
  })}"

  tags = {
    Name = "week05-k8s-master"
  }
}

resource "aws_instance" "worker" {
  count                  = 2
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = local.instance_type
  key_name               = var.key_name
  subnet_id              = local.lab_subnet_id
  vpc_security_group_ids = [aws_security_group.worker.id]
  iam_instance_profile   = var.lab_instance_profile

  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  user_data = "${file("${path.module}/bootstrap.sh")}\n${templatefile("${path.module}/worker-join.sh.tftpl", {
    k8s_token = local.k8s_token
    master_ip = aws_instance.master.private_ip
    node_name = "workernode${count.index + 1}"
  })}"

  tags = {
    Name = "week05-k8s-worker-${count.index + 1}"
  }
}

output "public_ips" {
  value = merge(
    { master = aws_instance.master.public_ip },
    { for i, w in aws_instance.worker : "worker-${i + 1}" => w.public_ip }
  )
}

output "private_ips" {
  value = merge(
    { master = aws_instance.master.private_ip },
    { for i, w in aws_instance.worker : "worker-${i + 1}" => w.private_ip }
  )
}

output "next_step" {
  value = "ssh -i <your-key.pem> ubuntu@${aws_instance.master.public_ip}   # then: kubectl get nodes"
}

output "nodeport_url" {
  value = "http://${aws_instance.master.public_ip}:30000/"
}
