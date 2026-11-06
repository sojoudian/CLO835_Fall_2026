#!/bin/bash
# CLO835 - Week 06 - Rollouts, Labels and Services.
# Run these ON THE MASTER NODE, section by section. Do NOT run the whole file.
#
# Terraform builds 3 machines: 1 control plane and 2 workers. The cluster forms
# itself at boot, the same way it did in Weeks 04 and 05.
#
# Each step matches one slide of Lab_week06_v4.pptx.

########################################################
# Step 0 - check the cluster                    (slide 3)
########################################################
# All three nodes must reach Ready. The workers take a few minutes to join.
kubectl get nodes -o wide
kubectl get pods -n kube-system

########################################################
# Step 1 - A Deployment from a manifest         (slide 4)
########################################################
# The Deployment of the lecture: 3 replicas of kubia version 1.
cat > deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kubia
spec:
  replicas: 3
  selector:
    matchLabels:
      app: kubia
  template:
    metadata:
      labels:
        app: kubia
    spec:
      terminationGracePeriodSeconds: 5
      containers:
      - name: kubia
        image: maziar/kubia:v1
        ports:
        - name: http
          containerPort: 8080
EOF
kubectl apply -f deployment.yaml
kubectl rollout status deployment/kubia

# One Deployment, one ReplicaSet, three Pods.
kubectl get deploy,rs,pods -o wide

########################################################
# Step 2 - Roll out version 2, then roll back   (slide 5)
########################################################
# Record why each revision exists. The history shows it.
kubectl annotate deployment/kubia kubernetes.io/change-cause="image maziar/kubia:v1"
kubectl set image deployment/kubia kubia=maziar/kubia:v2
kubectl annotate deployment/kubia kubernetes.io/change-cause="image maziar/kubia:v2"
kubectl rollout status deployment/kubia

# A second ReplicaSet holds the 3 Pods. The first one holds 0.
kubectl get rs -o wide
kubectl rollout history deployment/kubia

# Go back one revision. Revision 1 comes back as revision 3.
kubectl rollout undo deployment/kubia
kubectl rollout status deployment/kubia
kubectl rollout history deployment/kubia

########################################################
# Step 3 - Labels drive the ReplicaSet          (slide 6)
########################################################
# The ReplicaSet finds its Pods by the label app=kubia.
kubectl get pods --show-labels
kubectl get pods -l app=kubia

# Take the newest Pod out of the selector: change its label.
POD=$(kubectl get pods -l app=kubia --sort-by=.metadata.creationTimestamp \
    -o jsonpath='{.items[-1:].metadata.name}')
kubectl label pod $POD app=kubia-debug --overwrite

# The ReplicaSet sees 2 Pods, so it makes a third Pod at once.
kubectl rollout status deployment/kubia
kubectl get pods -L app

# The re-labelled Pod still runs. No object owns it now.
kubectl get pod $POD -o jsonpath='{.metadata.ownerReferences}'; echo

########################################################
# Step 4 - A ClusterIP Service and its DNS name (slide 7)
########################################################
# One stable address for the Pods with app=kubia.
cat > service.yaml <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: kubia
spec:
  selector:
    app: kubia
  ports:
  - name: http
    port: 80
    targetPort: http
EOF
kubectl apply -f service.yaml
kubectl get svc kubia
kubectl get endpointslices -l kubernetes.io/service-name=kubia
# 3 endpoints. The kubia-debug Pod is not one of them.

# A client Pod calls the Service by its name.
kubectl run client --image=maziar/alpine-curl --command -- sleep 3600
kubectl wait --for=condition=Ready pod/client --timeout=120s
for i in 1 2 3 4; do kubectl exec client -- curl -s http://kubia; done
kubectl exec client -- curl -s http://kubia.default.svc.cluster.local

########################################################
# Step 5 - A NodePort Service                   (slide 8)
########################################################
# A NodePort opens one port on EVERY node.
cat > service-nodeport.yaml <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: kubia-nodeport
spec:
  type: NodePort
  selector:
    app: kubia
  ports:
  - name: http
    port: 80
    targetPort: http
    nodePort: 30000
EOF
kubectl apply -f service-nodeport.yaml
kubectl get svc kubia-nodeport
sleep 2; curl -s http://localhost:30000

# ON YOUR OWN MACHINE, read the public addresses.
# ON YOUR OWN MACHINE:  terraform output public_ips
# Open http://<each-public-ip>:30000/ in a browser.
# All 3 nodes answer.

########################################################
# Step 6 - Clean up                             (slide 9)
########################################################
# ON THE MASTER - remove the Kubernetes objects.
bash cleanup_lab06.sh

# Confirm that nothing is left.
kubectl get all | grep -E 'kubia|client'

# ON YOUR OWN MACHINE - remove the three EC2 machines.
# ON YOUR OWN MACHINE:  terraform destroy          # asks for key_name again

# Always destroy. The Learner Lab budget is small.
