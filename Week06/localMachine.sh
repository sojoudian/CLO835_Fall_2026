#!/bin/bash
# CLO835 - Week 06 - Rollouts, Labels and Services.
# Run these ON THE MASTER NODE, section by section. Do NOT run the whole file.
#
# Terraform builds 3 machines: 1 control plane and 2 workers. The cluster forms
# itself at boot, the same way it did in Weeks 04 and 05. This week the subject
# is how a Deployment rolls out a new version, how labels select Pods, and how
# a Service gives a group of Pods one stable name and address.
#
# Each step matches one slide of Lab_week06_v2.pptx.

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
# Write deployment.yaml with a here-document.
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
        image: luksa/kubia:v1
        ports:
        - name: http
          containerPort: 8080
EOF
kubectl apply -f deployment.yaml
kubectl rollout status deployment/kubia

# One Deployment, one ReplicaSet, three Pods.
kubectl get deploy,rs,pods -o wide

# The container port has a name: http. Slide 17 uses it.
# This app ignores the stop signal. terminationGracePeriodSeconds: 5
# makes Kubernetes stop an old Pod after 5 seconds, not after 30.

########################################################
# Step 2 - Rolling out version 2                (slide 5)
########################################################
# Record why revision 1 exists. The rollout history shows it.
kubectl annotate deployment/kubia kubernetes.io/change-cause="image luksa/kubia:v1"

# A new image starts a rollout. The Deployment makes a second ReplicaSet.
kubectl set image deployment/kubia kubia=luksa/kubia:v2
kubectl annotate deployment/kubia kubernetes.io/change-cause="image luksa/kubia:v2"
kubectl rollout status deployment/kubia

# The old ReplicaSet now holds 0 Pods. The new one holds the 3 Pods.
kubectl get rs -o wide

# Ask the newest Pod which version it runs. The master reaches each Pod IP.
kubectl get pods -l app=kubia -o wide
curl -s $(kubectl get pods -l app=kubia --sort-by=.metadata.creationTimestamp \
    -o jsonpath='{.items[-1:].status.podIP}'):8080
# This is v2 running in pod kubia-...

########################################################
# Step 3 - Rollout history and rollback         (slide 6)
########################################################
# Each revision is one ReplicaSet. CHANGE-CAUSE shows the annotation.
kubectl rollout history deployment/kubia
kubectl rollout history deployment/kubia --revision=2

# Go back one revision. The v1 ReplicaSet scales up again.
kubectl rollout undo deployment/kubia
kubectl rollout status deployment/kubia

# Revision 1 is now revision 3. A rollback is a new rollout.
kubectl rollout history deployment/kubia

# Go to a named revision: back to v2.
kubectl rollout undo deployment/kubia --to-revision=2
kubectl rollout status deployment/kubia
kubectl get rs -o wide

########################################################
# Step 4 - A failed rollout                     (slide 7)
########################################################
# Roll out an image tag that does not exist, and record the change-cause.
kubectl set image deployment/kubia kubia=luksa/kubia:v9
kubectl annotate deployment/kubia kubernetes.io/change-cause="image luksa/kubia:v9"

# The rollout cannot finish. The status command stops after 60 seconds.
kubectl rollout status deployment/kubia --timeout=60s

# One new Pod cannot pull its image. The 3 old Pods still serve.
# 25% of 3 Pods rounds down to 0, so no old Pod may stop.
kubectl get pods -l app=kubia
kubectl get rs
kubectl get events --field-selector reason=Failed --sort-by=.lastTimestamp | tail -3

# Roll back the failed rollout.
kubectl rollout undo deployment/kubia
kubectl rollout status deployment/kubia
kubectl get pods -l app=kubia

########################################################
# Step 5 - Rollout strategy - Recreate          (slide 8)
########################################################
# The default strategy is RollingUpdate. Change this Deployment to Recreate.
kubectl patch deployment kubia \
    -p '{"spec":{"strategy":{"type":"Recreate","rollingUpdate":null}}}'
kubectl get deployment kubia -o jsonpath='{.spec.strategy}'; echo

# SECOND SSH SESSION - watch the Pods. Press Ctrl+C to stop.
kubectl get pods -l app=kubia -w

# FIRST SSH SESSION - roll out v1 with Recreate, and record the change-cause.
kubectl set image deployment/kubia kubia=luksa/kubia:v1
kubectl annotate deployment/kubia kubernetes.io/change-cause="image luksa/kubia:v1"
kubectl rollout status deployment/kubia
# All 3 old Pods stop first. Only then do the 3 new Pods start.

# Change the Deployment back to the default strategy.
kubectl patch deployment kubia -p '{"spec":{"strategy":{"type":"RollingUpdate"}}}'
kubectl get deployment kubia -o jsonpath='{.spec.strategy}'; echo

########################################################
# Step 6 - Pause and resume a rollout           (slide 9)
########################################################
# Pause: the Deployment accepts changes, but it does not roll them out.
kubectl rollout pause deployment/kubia
kubectl set image deployment/kubia kubia=luksa/kubia:v2
kubectl annotate deployment/kubia kubernetes.io/change-cause="image luksa/kubia:v2"

# The image is now v2, but UP-TO-DATE is 0. The v1 ReplicaSet keeps its 3 Pods.
kubectl get deployment kubia -o wide
kubectl get rs -o wide

# Resume: the change that waited rolls out now.
kubectl rollout resume deployment/kubia
kubectl rollout status deployment/kubia

# The v2 ReplicaSet from slide 5 gets the 3 Pods again. A Deployment
# reuses the ReplicaSet that has the same Pod template, so none is new.
kubectl get rs -o wide

########################################################
# Step 7 - Pods with labels                     (slide 12)
########################################################
# Two Pods: the first has no labels, the second has two.
cat > pods-with-labels.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: kubia-manual
spec:
  containers:
  - name: kubia
    image: luksa/kubia:v1
---
apiVersion: v1
kind: Pod
metadata:
  name: kubia-manual-v2
  labels:
    creation_method: manual
    env: prod
spec:
  containers:
  - name: kubia
    image: luksa/kubia:v1
EOF
kubectl apply -f pods-with-labels.yaml

# Show all the labels, or only some of them as columns.
kubectl get pods --show-labels
kubectl get pods -L creation_method,env

# Add a label. Change a label with --overwrite.
kubectl label pod kubia-manual creation_method=manual
kubectl label pod kubia-manual-v2 env=debug --overwrite
kubectl get pods -L creation_method,env

########################################################
# Step 8 - Select Pods with a label selector    (slide 13)
########################################################
# Equality: the label has this value.
kubectl get pods -l creation_method=manual
kubectl get pods --selector app=kubia

# Existence: the Pod has the label, or it does not have the label.
kubectl get pods -l env
kubectl get pods -l '!env'

# Set: the value is one of a list.
kubectl get pods -l 'env in (prod,debug)'

# Two conditions: both must be true.
kubectl get pods -l creation_method=manual,env=debug

########################################################
# Step 9 - Labels drive the ReplicaSet          (slide 14)
########################################################
# A ReplicaSet finds its Pods by label. Read its selector.
kubectl get rs -l app=kubia -o wide
kubectl get pods -l app=kubia --show-labels

# Take one Pod out of the selector.
POD=$(kubectl get pods -l app=kubia --sort-by=.metadata.creationTimestamp \
    -o jsonpath='{.items[-1:].metadata.name}')
kubectl label pod $POD app=kubia-debug --overwrite

# The ReplicaSet sees 2 Pods, and it makes a third Pod at once.
kubectl get pods -L app

# The re-labelled Pod still runs, but no object owns it now.
kubectl get pod $POD -o jsonpath='{.metadata.ownerReferences}'; echo

########################################################
# Step 10 - A ClusterIP Service                 (slide 17)
########################################################
# One stable address for the 3 Pods. ClusterIP is the default type.
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

# targetPort: http is the NAME of the container port 8080.
# The endpoints are the Pods with app=kubia. The kubia-debug
# Pod is not one of them.
kubectl describe svc kubia
kubectl get endpointslices -l kubernetes.io/service-name=kubia

########################################################
# Step 11 - Reach the Service from inside the cluster (slide 18)
########################################################
# Way 1 - a client Pod calls the Service by its name.
kubectl run client --image=alpine:3.22 --command -- sleep 3600
kubectl wait --for=condition=Ready pod/client --timeout=120s
for i in 1 2 3 4 5; do kubectl exec client -- wget -qO- http://kubia; done
# The Service spreads the calls over the Pods.

# Way 2 - run curl inside one of the kubia Pods.
kubectl exec deploy/kubia -- curl -s http://kubia

# Way 3 - on a node, call the ClusterIP. The master is a node.
curl -s http://$(kubectl get svc kubia -o jsonpath='{.spec.clusterIP}')

########################################################
# Step 12 - Endpoints follow the Pods           (slide 19)
########################################################
# Scale down. The Service keeps one endpoint: a Pod that is ready.
kubectl scale deployment kubia --replicas=1
kubectl describe svc kubia | grep Endpoints

# Scale to zero. A stopping Pod still answers, so wait until it is gone.
kubectl scale deployment kubia --replicas=0
kubectl wait --for=delete pod -l app=kubia --timeout=60s
kubectl describe svc kubia | grep Endpoints

# No Pod, no endpoint: the call fails.
kubectl exec client -- wget -qO- -T 5 http://kubia
# wget: can't connect to remote host (10.x.x.x): Connection refused

# Scale back to 3. The endpoints come back by themselves.
kubectl scale deployment kubia --replicas=3
kubectl rollout status deployment/kubia
kubectl describe svc kubia | grep Endpoints

########################################################
# Step 13 - kube-proxy writes the rules         (slide 20)
########################################################
# kube-proxy runs on every node, as one Pod of a DaemonSet.
kubectl get pods -n kube-system -l k8s-app=kube-proxy -o wide

# A Service has no process. It is a set of rules in the kernel.
sudo iptables-save -t nat | grep 'default/kubia:http' | head -5

# kube-proxy writes the same rules on each node. A call to the
# ClusterIP on any node reaches a Pod on any node.

########################################################
# Step 14 - A NodePort Service                  (slide 21)
########################################################
# A NodePort opens one port on EVERY node.
# Terraform opens 30000-32767 on all three nodes.
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

# A NodePort Service also gets a ClusterIP.
kubectl get svc kubia-nodeport
# kube-proxy needs a moment to write the rules.
sleep 2; curl -s http://localhost:30000

# ON YOUR OWN MACHINE, read the public addresses.
# ON YOUR OWN MACHINE:  terraform output public_ips
# Open http://<each-public-ip>:30000/ in a browser. All 3 answer.

########################################################
# Step 15 - A LoadBalancer Service on kubeadm   (slide 22)
########################################################
# kubeadm has no cloud load balancer. Ask for one anyway.
kubectl expose deployment kubia --name=kubia-lb --type=LoadBalancer \
    --port=80 --target-port=http

# EXTERNAL-IP stays <pending>: no controller gives an address.
kubectl get svc kubia-lb

# The Service still works, through the NodePort that it got.
NP=$(kubectl get svc kubia-lb -o jsonpath='{.spec.ports[0].nodePort}')
echo $NP
sleep 2; curl -s http://localhost:$NP

# A cloud provider fills EXTERNAL-IP with the address of its load balancer.

########################################################
# Step 16 - A rolling update through the Service (slide 23)
########################################################
# SECOND SSH SESSION - call the Service once a second, for 40 seconds.
kubectl exec client -- sh -c \
    'for i in $(seq 1 40); do wget -qO- -T 2 http://kubia; sleep 1; done'

# FIRST SSH SESSION - roll out v1 with the default RollingUpdate.
kubectl set image deployment/kubia kubia=luksa/kubia:v1
kubectl annotate deployment/kubia kubernetes.io/change-cause="image luksa/kubia:v1"
kubectl rollout status deployment/kubia

# The second session shows v2 answers, then v1 answers. While both
# versions run, the answers can mix. No call fails: an old Pod stops
# only after a new Pod is ready.

########################################################
# Step 17 - Ingress needs a controller          (slide 24)
########################################################
# An Ingress routes HTTP calls by host and path to a Service.
cat > ingress.yaml <<'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: kubia
spec:
  rules:
  - host: kubia.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: kubia-nodeport
            port:
              number: 80
EOF
kubectl apply -f ingress.yaml

# The API server keeps the rule, but ADDRESS stays empty.
kubectl get ingress kubia

# No ingress controller runs in this cluster.
# So no program reads the rule, and no program serves it.
kubectl get ingressclass

########################################################
# Step 18 - Discovery through DNS               (slide 27)
########################################################
# CoreDNS answers the names. Its Service is kube-dns.
kubectl get svc -n kube-system kube-dns
kubectl get pods -n kube-system -l k8s-app=kube-dns -o wide

# Each Pod sends its DNS questions to the ClusterIP of kube-dns.
kubectl exec client -- cat /etc/resolv.conf

# The full name, a short form, and the short name all work.
kubectl exec client -- wget -qO- http://kubia.default.svc.cluster.local
kubectl exec client -- wget -qO- http://kubia.default
kubectl exec client -- wget -qO- http://kubia

########################################################
# Step 19 - Discovery through environment variables (slide 28)
########################################################
# A Pod gets variables for each Service that exists when the Pod starts.
kubectl exec client -- env | grep KUBIA_SERVICE

# kubia-manual started before the Service, so it has no such variable.
kubectl exec kubia-manual -- env | grep KUBIA_SERVICE

# DNS has no such limit. Each Pod resolves each Service name.
kubectl exec kubia-manual -- curl -s http://kubia

########################################################
# Step 20 - The Service name is the contract    (slide 29)
########################################################
# A client calls a Service by its name. Give the same Pods a second name.
kubectl expose deployment kubia --name=kubia-v2 --port=80 --target-port=http
# kube-proxy needs a moment to write the rules.
sleep 2; kubectl exec client -- wget -qO- -T 5 http://kubia-v2

# Delete the first name. A client that still calls it fails.
# CoreDNS and kube-proxy need a moment to remove the name and the rules.
kubectl delete service kubia
sleep 2; kubectl exec client -- wget -qO- -T 5 http://kubia
# wget: bad address 'kubia'

# The Pods did not change. Only the name is gone.
kubectl get pods -l app=kubia

########################################################
# Step 21 - Clean up                            (slide 30)
########################################################
# ON THE MASTER - remove the Kubernetes objects.
bash cleanup_lab06.sh

# Confirm that nothing is left.
kubectl get all,ingress | grep -E 'kubia|client'

# ON YOUR OWN MACHINE - remove the three EC2 machines.
# ON YOUR OWN MACHINE:  terraform destroy

# Always destroy. The Learner Lab budget is small.
