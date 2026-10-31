#!/bin/bash
# CLO835 - Week 10 - PersistentVolumes, StorageClasses and StatefulSets.
# Run these ON THE MASTER NODE, section by section. Do NOT run the whole file.
#
# Terraform builds 3 machines: 1 control plane and 2 workers. The cluster forms
# itself at boot, the same way it did in Weeks 04 to 09.
#
# Each step matches one slide of Lab_week10_v2.pptx.

########################################################
# Step 0 - check the cluster                    (slide 3)
########################################################
# All three nodes must reach Ready. The workers take a few minutes to join.
kubectl get nodes -o wide
kubectl get pods -n kube-system

########################################################
# Step 1 - A PersistentVolume and a claim       (slide 4)
########################################################
# The administrator makes the PV: a folder of
# workernode1. The user claims it with a PVC.
cat > pv-pvc.yaml <<'EOF'
apiVersion: v1
kind: PersistentVolume
metadata:
  name: data-pv
spec:
  capacity: {storage: 1Gi}
  accessModes: [ReadWriteOnce]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: ""
  hostPath: {path: /tmp/data-pv, type: DirectoryOrCreate}
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values: [workernode1]
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: data-pvc
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: ""
  resources: {requests: {storage: 1Gi}}
EOF
kubectl apply -f pv-pvc.yaml

# The claim finds the PV: both become Bound.
kubectl wait --for=jsonpath='{.status.phase}'=Bound pvc/data-pvc --timeout=60s
kubectl get pv,pvc

# Retain: when the claim goes, the PV and its
# data stay for the administrator.

########################################################
# Step 2 - The data outlives the Pod            (slide 5)
########################################################
# The Pod names the claim, not the storage.
cat > writer.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: writer
spec:
  containers:
  - name: shell
    image: busybox:1.36
    command: ["sleep", "3600"]
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: data-pvc
EOF
kubectl apply -f writer.yaml
kubectl wait --for=condition=Ready pod/writer --timeout=120s
kubectl get pod writer -o wide     # on workernode1
kubectl exec writer -- sh -c 'date > /data/note.txt'

# Delete the Pod. A new Pod gets the same data.
kubectl delete pod writer --now
kubectl apply -f writer.yaml
kubectl wait --for=condition=Ready pod/writer --timeout=120s
kubectl exec writer -- cat /data/note.txt

########################################################
# Step 3 - A StorageClass provisions the volumes (slide 6)
########################################################
# On EKS, the EBS CSI driver makes a disk for each claim. Here the local-path
# provisioner of the course repository makes a folder on a node.
kubectl apply -f https://raw.githubusercontent.com/sojoudian/CLO835_Fall_2026/master/Week10/local-path-storage.yaml
kubectl -n local-path-storage rollout status deployment/local-path-provisioner

# One StorageClass, the default. A claim with no class gets it.
kubectl get storageclass
# NAME                 PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE
# standard (default)   rancher.io/local-path   Delete          WaitForFirstConsumer

# WaitForFirstConsumer: the PV is made only when a Pod uses the claim.

########################################################
# Step 4 - A StatefulSet and its headless Service (slide 7)
########################################################
# The headless Service (no ClusterIP) names the pets.
kubectl create service clusterip kubia --clusterip=None --tcp=80:8080

# Each pet gets a claim from the template, and the
# StorageClass makes a PV for each claim.
cat > kubia-statefulset.yaml <<'EOF'
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: kubia
spec:
  serviceName: kubia
  replicas: 2
  selector:
    matchLabels: {app: kubia}
  template:
    metadata:
      labels: {app: kubia}
    spec:
      containers:
      - name: kubia
        image: maziar/kubia-pet
        ports:
        - {name: http, containerPort: 8080}
        volumeMounts:
        - {name: data, mountPath: /var/data}
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: [ReadWriteOnce]
      resources: {requests: {storage: 1Mi}}
EOF
kubectl apply -f kubia-statefulset.yaml

# kubia-0 first, then kubia-1. Each has its own PV.
kubectl rollout status statefulset/kubia --timeout=300s
kubectl get pods -l app=kubia -o wide
kubectl get pvc,pv

########################################################
# Step 5 - A pet keeps its name, its data and its DNS name (slide 8)
########################################################
# kubectl proxy listens on 8001 and adds your credentials to each request.
kubectl proxy --port=8001 >/dev/null 2>&1 &
sleep 2; curl -s -X POST -d 'Hello kubia-0' localhost:8001/api/v1/namespaces/default/pods/kubia-0/proxy/
curl -s localhost:8001/api/v1/namespaces/default/pods/kubia-0/proxy/

# Delete kubia-0. The StatefulSet makes a new kubia-0 with the same claim.
kubectl delete pod kubia-0
sleep 5; kubectl wait --for=condition=Ready pod/kubia-0 --timeout=180s
curl -s localhost:8001/api/v1/namespaces/default/pods/kubia-0/proxy/          # the same data

# The headless Service gives each pet a stable DNS name.
kubectl run dnstest --image=maziar/alpine-curl --restart=Never --command -- sleep 3600
kubectl wait --for=condition=Ready pod/dnstest --timeout=120s
kubectl exec dnstest -- nslookup kubia-0.kubia.default.svc.cluster.local

########################################################
# Step 6 - Clean up                             (slide 9)
########################################################
# ON THE MASTER - stop the proxy and remove the Kubernetes objects.
bash cleanup_lab10.sh

# Confirm that nothing is left.
kubectl get pods,pvc,pv

# ON YOUR OWN MACHINE - remove the three EC2 machines.
# ON YOUR OWN MACHINE:  terraform destroy          # asks for key_name again

# Always destroy. The Learner Lab budget is small.
