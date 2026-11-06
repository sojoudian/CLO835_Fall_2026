#!/bin/bash
# CLO835 Week 03 - prepare the machine for the Docker lab.
#
# Every step of this lab is a docker command, so the engine must be ready
# before you log in. This installs Docker Engine from the official Docker
# repository, starts it, and adds ubuntu to the docker group.

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

# The lab scans an image. docker scout is a Docker Desktop plugin and is NOT
# on a server, so the lab uses the trivy container instead. Pull it now.
docker pull aquasec/trivy:latest || true

cat > /etc/motd <<'MOTD'

  CLO835 - Week 03 - Docker networking, storage and security
  ----------------------------------------------------------
  Docker is installed and running. You are in the docker group.
  Follow localMachine.sh, section by section.

  Check first:   docker version

  Note: docker scout is not on a server. Use the trivy line instead.

MOTD
