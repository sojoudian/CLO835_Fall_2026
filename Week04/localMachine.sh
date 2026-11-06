#!/bin/bash
# CLO835 - Week 04 - a real Kubernetes cluster with kubeadm.
# Run these ON THE MASTER NODE, section by section. Do NOT run the whole file.
#
# Terraform builds 3 machines: 1 control plane and 2 workers. The cluster forms
# itself at boot. No kind, no Docker-in-Docker. This is kubeadm on real VMs.

########################################################
# Step 0 - check the cluster
########################################################
kubectl version
kubectl cluster-info

# All three nodes must reach Ready. The workers take a few minutes to join.
kubectl get nodes -o wide

# Watch them arrive, then press Ctrl+C:
#   kubectl get nodes -w

########################################################
# Step 1 - what the control plane runs
########################################################
# Every control-plane component runs as a static pod on the master.
kubectl get pods -n kube-system -o wide

# Flannel is the CNI. One pod per node gives the flat 10.244.0.0/16 pod network.
kubectl get pods -n kube-flannel -o wide

########################################################
# Step 2 - deploy your first application
########################################################
kubectl run nginx --image=nginx --port=80
kubectl get pods -o wide            # note WHICH node the scheduler picked
kubectl describe pod nginx | head -20

########################################################
# Step 3 - expose it with a Service
########################################################
kubectl expose pod nginx --type=NodePort --name=nginx-http \
    --port=80 --target-port=80

# A NodePort gets a random port in 30000-32767. Pin it to 30000 so you always
# know the address.
kubectl patch svc nginx-http -p '{"spec":{"ports":[{"port":80,"targetPort":80,"nodePort":30000}]}}'

kubectl get services
kubectl describe svc nginx-http | head -15

########################################################
# Step 4 - reach it
########################################################
# From the master:
curl -s http://localhost:30000 | head -5

# A NodePort opens on EVERY node, not only the one running the pod.
# Try all three public IPs from the terraform output. All three answer:
#   http://<MASTER-PUBLIC-IP>:30000
#   http://<WORKER1-PUBLIC-IP>:30000
#   http://<WORKER2-PUBLIC-IP>:30000

########################################################
# Step 5 - scale, inspect, roll forward
########################################################
kubectl create deployment nginx-deploy --image=nginx --replicas=3
kubectl rollout status deployment/nginx-deploy
kubectl get pods -l app=nginx-deploy -o wide   # spread across the 2 workers

kubectl scale deploy nginx-deploy --replicas=5
kubectl get pods -l app=nginx-deploy -o wide

# The Deployment owns a ReplicaSet, and the ReplicaSet owns the Pods.
kubectl get deploy,rs,pods -l app=nginx-deploy

kubectl set image deployment/nginx-deploy nginx=nginx:1.27
kubectl rollout status deployment/nginx-deploy
kubectl rollout undo deployment/nginx-deploy
kubectl rollout status deployment/nginx-deploy

########################################################
# Step 6 - clean up
########################################################
./cleanup_lab04.sh
