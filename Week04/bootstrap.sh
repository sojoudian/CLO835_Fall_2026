#!/bin/bash
# CLO835 Week 04 - prepare the machine for the kind lab.
#
# kind runs a whole Kubernetes control plane inside a Docker container, so the
# machine needs Docker, kind and kubectl before you log in.

set -eux
export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get install -y ca-certificates curl

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  > /etc/apt/sources.list.d/docker.list

apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable --now docker
usermod -aG docker ubuntu

# kind
curl -sLo /tmp/kind https://kind.sigs.k8s.io/dl/v0.31.0/kind-linux-amd64
install -o root -g root -m 0755 /tmp/kind /usr/local/bin/kind

# kubectl, the same MINOR version as the cluster kind creates
curl -sLo /tmp/kubectl https://dl.k8s.io/release/v1.35.0/bin/linux/amd64/kubectl
install -o root -g root -m 0755 /tmp/kubectl /usr/local/bin/kubectl

cat > /etc/motd <<'MOTD'

  CLO835 - Week 04 - kind cluster lab
  -----------------------------------
  Docker, kind and kubectl are installed. You are in the docker group.
  Follow localMachine.sh, section by section.

  Check first:   docker version && kind version && kubectl version --client

MOTD
