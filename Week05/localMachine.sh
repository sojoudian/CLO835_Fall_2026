#!/bin/bash
# CLO835 - Week 05 - Pods, ReplicaSets and Deployments.
# Run these ON THE MASTER NODE, section by section. Do NOT run the whole file.
#
# Terraform builds 3 machines: 1 control plane and 2 workers. The cluster forms
# itself at boot, the same way it did in Week 04. This week the subject is what
# runs ON the cluster: Pods, labels, ReplicaSets and Deployments.
#
# Each step matches one slide of Lab_week05.pptx.

########################################################
# Step 0 - check the cluster                    (slide 3)
########################################################
# All three nodes must reach Ready. The workers take a few minutes to join.
kubectl get nodes -o wide
kubectl get pods -n kube-system

# A short alias. Every step below also works with the full word.
alias k=kubectl

########################################################
# Step 1 - your first Pod                       (slide 4)
########################################################
kubectl run nginx --image nginx
kubectl get pods
kubectl get pods --all-namespaces

# The API server stores far more than you typed. Read it back.
kubectl get pod nginx -o yaml

# Reach it without publishing anything, through a port forward.
kubectl wait --for=condition=Ready pod/nginx --timeout=120s
kubectl port-forward nginx 8080:80 &
sleep 3
curl -s http://localhost:8080 | head -5
kill %1

########################################################
# Step 2 - a Pod from a manifest                (slide 5)
########################################################
# Write the manifest instead of creating the Pod directly.
kubectl run kubia --image maziar/kubia --dry-run=client -o yaml > kubia-manual.yaml
cat kubia-manual.yaml
kubectl apply -f kubia-manual.yaml
kubectl get pods

# Read the schema before you write YAML by hand.
kubectl explain pod.spec
kubectl explain pod.spec.containers

########################################################
# Step 3 - two containers in one Pod            (slide 6)
########################################################
# A Pod may hold more than one container. They share one IP address and one
# network namespace, so they reach each other on 127.0.0.1.
cat > sidecar.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: web-with-sidecar
  labels:
    app: web
spec:
  containers:
  - name: web
    image: nginx
  - name: logger
    image: alpine
    command: ["sh", "-c", "while true; do date; sleep 5; done"]
EOF
kubectl apply -f sidecar.yaml

# READY reads 2/2, because the Pod holds two containers.
kubectl get pod web-with-sidecar

# -c picks which container you read.
kubectl logs web-with-sidecar -c logger

########################################################
# Step 4 - logs                                 (slide 7)
########################################################
kubectl run pingpong --image alpine ping 127.0.0.1
kubectl logs pingpong
kubectl logs pingpong -c pingpong
kubectl logs pingpong --tail 1 --follow   # press Ctrl+C to stop
kubectl get po pingpong -o yaml

########################################################
# Step 5 - labels and selectors                 (slide 8)
########################################################
# A label is a key and a value. A selector picks objects by label.
kubectl label pod nginx app=web rel=stable
kubectl label pod kubia app=kubia rel=beta
kubectl get pods --show-labels

# Select by label. A ReplicaSet uses this same mechanism internally.
kubectl get pods -l app=web
kubectl get pods -l 'rel in (stable,beta)'
kubectl get pods -l app!=web

# Change one label, then select again. The result changes.
kubectl label pod nginx rel=canary --overwrite
kubectl get pods -l rel=canary

########################################################
# Step 6 - a Pod does not scale, a Deployment does  (slide 9)
########################################################
# This FAILS, and that is the lesson.
kubectl scale pod pingpong --replicas=3

# A Deployment can. Give it its own namespace.
kubectl create ns pingpong
kubectl create deployment pingpong --image=alpine:3.14 -n pingpong -- ping 127.0.0.1

# Three objects appear: a Deployment, a ReplicaSet and a Pod.
kubectl get all -n pingpong

########################################################
# Step 7 - a ReplicaSet from a descriptor       (slide 10)
########################################################
# Write a ReplicaSet by hand, the way the lecture shows it. The selector is how
# the ReplicaSet finds the Pods it owns, so it must match the template labels.
cat > rs.yaml <<'EOF'
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: kubia-rs
spec:
  replicas: 3
  selector:
    matchLabels:
      app: kubia-rs
  template:
    metadata:
      labels:
        app: kubia-rs
    spec:
      containers:
      - name: kubia
        image: maziar/kubia
EOF
kubectl apply -f rs.yaml

kubectl get rs kubia-rs
kubectl get pods -l app=kubia-rs

########################################################
# Step 8 - scaling                              (slide 11)
########################################################
kubectl scale deployment pingpong --replicas 3 -n pingpong
kubectl get all -n pingpong

kubectl scale deployment pingpong --replicas 1 -n pingpong
kubectl get all -n pingpong

########################################################
# Step 9 - roll forward                         (slides 12 and 13)
########################################################
# Move alpine 3.14 to 3.15 without stopping the service.
kubectl set image deployment/pingpong alpine=alpine:3.15 -n pingpong
kubectl rollout status deployment/pingpong -n pingpong

# A second ReplicaSet appears. The first one scales down to zero.
kubectl get all -n pingpong
kubectl get rs -n pingpong

########################################################
# Step 10 - roll back                           (slide 14)
########################################################
# A Deployment keeps its old ReplicaSets, so you can go back.
kubectl rollout history deployment/pingpong -n pingpong
kubectl rollout undo deployment/pingpong -n pingpong
kubectl rollout status deployment/pingpong -n pingpong
kubectl get all -n pingpong

########################################################
# Step 11 - resilience                          (slide 15)
########################################################
kubectl scale deployment pingpong --replicas 3 -n pingpong
kubectl get pods -n pingpong

# Delete one Pod by name. The ReplicaSet replaces it at once.
kubectl delete pod <paste-one-pod-name-here> -n pingpong
kubectl get pods -n pingpong

# Now delete the stand-alone Pod. NOTHING replaces it.
kubectl delete pod pingpong
kubectl get pods

########################################################
# Step 12 - reach a Pod from your browser       (slide 16)
########################################################
# Nothing above left the cluster. Publish the nginx Pod.
kubectl expose pod nginx --type=NodePort --port=80 --name=nginx-http

# A NodePort gets a random port in 30000-32767. Pin it to 30000.
kubectl patch svc nginx-http -p '{"spec":{"ports":[{"port":80,"targetPort":80,"nodePort":30000}]}}'
kubectl get svc nginx-http

# From the master:
curl -s http://localhost:30000 | head -5

# A NodePort opens on EVERY node, not only the one running the Pod.
# Try all three public IPs from the terraform output. All three answer:
#   http://<MASTER-PUBLIC-IP>:30000
#   http://<WORKER1-PUBLIC-IP>:30000
#   http://<WORKER2-PUBLIC-IP>:30000

########################################################
# Step 13 - clean up                            (slide 17)
########################################################
./cleanup_lab05.sh
