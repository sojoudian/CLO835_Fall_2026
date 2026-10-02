#!/bin/bash
# CLO835 - Week 04 - a Kubernetes cluster with kind.
# Run these ON THE EC2 MACHINE, section by section. Do NOT run the whole file.

########################################################
# Step 0 - check the tools
########################################################
docker version
kind version
kubectl version --client

########################################################
# Step 1 - write the cluster description and create it
########################################################
cat > kind.yaml <<'EOF'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 30000
    hostPort: 30000
  - containerPort: 30001
    hostPort: 30001
EOF

kind create cluster --config kind.yaml

# The output must end with:   Set kubectl context to "kind-kind"
kubectl cluster-info
kubectl get nodes -o wide

########################################################
# Step 2 - deploy your first application
########################################################
kubectl run nginx --image=nginx --port=80
kubectl get pods
kubectl describe pod nginx | head -20

########################################################
# Step 3 - expose it with a Service
########################################################
# nodePort must sit inside the range the kind config maps: 30000 or 30001.
kubectl expose pod nginx --type=NodePort --name=nginx-http \
    --port=80 --target-port=80

# Pin the node port to 30000 so the mapping in kind.yaml reaches it.
kubectl patch svc nginx-http -p '{"spec":{"ports":[{"port":80,"targetPort":80,"nodePort":30000}]}}'

kubectl get services
kubectl describe svc nginx-http | head -15

########################################################
# Step 4 - reach it
########################################################
# from the machine itself
curl -s http://localhost:30000 | head -5

# from your own browser, with the public_ip output of Terraform:
#   http://<PUBLIC-IP>:30000

########################################################
# Step 5 - scale, inspect, roll forward
########################################################
kubectl create deployment nginx-deploy --image=nginx --replicas=3
kubectl get pods -l app=nginx-deploy

kubectl scale deploy nginx-deploy --replicas=5
kubectl get pods -l app=nginx-deploy

kubectl set image deployment/nginx-deploy nginx=nginx:1.27
kubectl rollout status deployment/nginx-deploy
kubectl rollout undo deployment/nginx-deploy
kubectl rollout status deployment/nginx-deploy

########################################################
# Step 6 - clean up
########################################################
./cleanup_lab04.sh
