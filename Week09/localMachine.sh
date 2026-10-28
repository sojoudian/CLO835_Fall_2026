#!/bin/bash
# CLO835 - Week 09 - Managed vs Self-managed Kubernetes.
# Run these ON THE MASTER NODE, section by section. Do NOT run the whole file.
#
# Terraform builds 3 machines: 1 control plane and 2 workers. The cluster forms
# itself at boot, the same way it did in Weeks 04 to 07. The lecture teaches
# what Amazon EKS runs for you. This lab does those jobs by hand.
#
# Each step matches one slide of Lab_week09_v2.pptx.

########################################################
# Step 0 - check the cluster                    (slide 3)
########################################################
# All three nodes must reach Ready. The workers take a few minutes to join.
kubectl get nodes -o wide
kubectl get pods -n kube-system

########################################################
# Step 1 - The control plane runs as static Pods (slide 4)
########################################################
# On EKS, AWS runs the control plane, and you never see it. Here the master runs it.
# The kubelet of the master starts every file of this folder as a static Pod.
sudo ls /etc/kubernetes/manifests
kubectl get pods -n kube-system -o wide | grep masternode

# No Deployment owns these Pods. Their owner is the node itself.
kubectl get pod kube-scheduler-masternode -n kube-system \
    -o jsonpath='{.metadata.ownerReferences[0].kind}{"\n"}'
# Node

########################################################
# Step 2 - etcd: the cluster database           (slide 5)
########################################################
# Every object of the cluster is a key in etcd. EKS runs etcd for you on three Availability Zones.
# Here it is one Pod on one machine. Ask it directly, with its own certificates.
ETCD="etcdctl --endpoints=https://127.0.0.1:2379 \
    --cacert=/etc/kubernetes/pki/etcd/ca.crt \
    --cert=/etc/kubernetes/pki/etcd/server.crt \
    --key=/etc/kubernetes/pki/etcd/server.key"
kubectl -n kube-system exec etcd-masternode -- $ETCD endpoint health
kubectl -n kube-system exec etcd-masternode -- $ETCD member list -w table
kubectl -n kube-system exec etcd-masternode -- $ETCD get /registry/namespaces --prefix --keys-only

# One member: no high availability. If this machine fails, the cluster stops.

########################################################
# Step 3 - You operate the control plane: stop the scheduler (slide 6)
########################################################
# On EKS you never touch the scheduler. Here it is a file. Move the file away.
sudo mv /etc/kubernetes/manifests/kube-scheduler.yaml /tmp/
kubectl wait --for=delete pod/kube-scheduler-masternode -n kube-system --timeout=90s
kubectl get pods -n kube-system -l component=kube-scheduler   # No resources found

# With no scheduler, a new Pod waits for a node.
kubectl run no-scheduler --image=maziar/kubia:v1
sleep 5; kubectl get pod no-scheduler -o wide                  # Pending, NODE <none>

# Put the file back. The scheduler starts, and it places the Pod.
sudo mv /tmp/kube-scheduler.yaml /etc/kubernetes/manifests/
kubectl wait --for=condition=Ready pod/no-scheduler --timeout=120s
kubectl get pod no-scheduler -o wide                           # Running on a worker

########################################################
# Step 4 - Certificates, upgrades and new nodes are your job (slide 7)
########################################################
# kubeadm made the certificates of the cluster. They expire one year after kubeadm init.
sudo kubeadm certs check-expiration

# EKS upgrades the control plane for you. Here you plan the upgrade yourself.
# It only reads. It changes nothing.
sudo kubeadm upgrade plan 2>&1 | tail -15

# A managed node group joins by itself. A new EC2 worker would run this command:
sudo kubeadm token create --print-join-command
# kubeadm join 172.31.x.x:6443 --token ... --discovery-token-ca-cert-hash sha256:...

########################################################
# Step 5 - Drain a node, as AWS does for a managed node group (slide 8)
########################################################
kubectl create deployment kubia --image=maziar/kubia:v1 --replicas=4
kubectl rollout status deployment/kubia
kubectl get pods -l app=kubia -o wide             # spread over both workers

# Maintenance on workernode2: stop new Pods there, then move its Pods away.
kubectl cordon workernode2
kubectl drain workernode2 --ignore-daemonsets --delete-emptydir-data --force
kubectl get pods -l app=kubia -o wide             # all four on workernode1
kubectl get nodes                                 # workernode2 SchedulingDisabled

# The maintenance is done. Let the node take Pods again.
kubectl uncordon workernode2
kubectl get nodes

########################################################
# Step 6 - Clean up                             (slide 9)
########################################################
# ON THE MASTER - remove the Kubernetes objects.
bash cleanup_lab09.sh

# Confirm that nothing is left.
kubectl get pods,deployments | grep -E 'kubia|no-scheduler'

# ON YOUR OWN MACHINE - remove the three EC2 machines.
# ON YOUR OWN MACHINE:  terraform destroy          # asks for key_name again

# Always destroy. The Learner Lab budget is small.
