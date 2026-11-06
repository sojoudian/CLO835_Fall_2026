#!/bin/bash
# CLO835 Week 04 - kubeadm node prerequisites. This runs on EVERY node.
# Terraform runs it at boot, as root, through user_data.
# To run it by hand on a node:  sudo bash bootstrap.sh
set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive

# 1. Turn swap off. kubelet refuses to start while swap is on.
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab

# 2. Pin the network interface to a 1500-byte MTU.
#    AWS gives these instances 9001-byte jumbo frames. Flannel then builds an
#    8951-byte overlay. A NodePort reply bigger than 1500 bytes is dropped on
#    the way to a browser on the internet, so the page never loads while the
#    headers arrive fine. 1500 here makes Flannel compute 1450.
IFACE=$(ip route show default | awk '{print $5; exit}')
ip link set dev "$IFACE" mtu 1500

cat >/etc/systemd/system/lab-mtu.service <<SVC
[Unit]
Description=Pin the lab interface MTU to 1500
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'ip link set dev \$(ip route show default | awk "{print \\\$5; exit}") mtu 1500'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
SVC
systemctl enable lab-mtu.service

# 3. Kernel modules and sysctls for the pod network.
cat >/etc/modules-load.d/k8s.conf <<'MOD'
overlay
br_netfilter
MOD
modprobe overlay
modprobe br_netfilter

cat >/etc/sysctl.d/k8s.conf <<'SYS'
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
SYS
sysctl --system

# 4. containerd, with the systemd cgroup driver.
apt-get update -y
apt-get install -y containerd apt-transport-https ca-certificates curl gpg conntrack socat ethtool
mkdir -p /etc/containerd
containerd config default >/etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
systemctl restart containerd
systemctl enable containerd

# 5. kubeadm, kubelet and kubectl, Kubernetes v1.35.
mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.35/deb/Release.key \
  | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.35/deb/ /" \
  >/etc/apt/sources.list.d/kubernetes.list
apt-get update -y
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl
systemctl enable kubelet

echo "Prerequisites installed."
