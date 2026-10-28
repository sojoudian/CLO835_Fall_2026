#!/bin/bash
# CLO835 - Week 07 - Volumes: attaching storage to containers.
# Run these ON THE MASTER NODE, section by section. Do NOT run the whole file.
#
# Terraform builds 3 machines: 1 control plane and 2 workers. The cluster forms
# itself at boot, the same way it did in Weeks 04 to 06.
#
# Each step matches one slide of Lab_week07_v2.pptx.

########################################################
# Step 0 - check the cluster                    (slide 3)
########################################################
# All three nodes must reach Ready. The workers take a few minutes to join.
kubectl get nodes -o wide
kubectl get pods -n kube-system

########################################################
# Step 1 - Two containers share one emptyDir    (slide 4)
########################################################
# html-generator writes a new fortune every 10 s into
# an emptyDir. nginx serves the same folder.
cat > fortune-pod.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: fortune
spec:
  containers:
  - image: maziar/fortune:env
    name: html-generator
    env:
    - name: INTERVAL
      value: "10"
    volumeMounts:
    - name: html
      mountPath: /var/htdocs
  - image: nginx:alpine
    name: web-server
    volumeMounts:
    - name: html
      mountPath: /usr/share/nginx/html
      readOnly: true
    ports:
    - containerPort: 80
  volumes:
  - name: html
    emptyDir: {}
EOF
kubectl apply -f fortune-pod.yaml
kubectl wait --for=condition=Ready pod/fortune --timeout=120s

# The master reaches each Pod IP. Call nginx 2 times.
POD_IP=$(kubectl get pod fortune -o jsonpath='{.status.podIP}')
curl -s http://$POD_IP; sleep 10; curl -s http://$POD_IP

# The volume shadows the folder: only the fortune file.
kubectl exec fortune -c web-server -- ls /usr/share/nginx/html

########################################################
# Step 2 - The volume lives as long as the Pod  (slide 5)
########################################################
# A container restart keeps the volume. Stop nginx: the kubelet starts it again.
kubectl exec fortune -c web-server -- nginx -s stop
sleep 5; kubectl get pod fortune                  # RESTARTS is now 1
curl -s http://$POD_IP                            # the fortune is still there

# A new Pod gets a new, empty volume.
kubectl delete pod fortune
kubectl apply -f fortune-pod.yaml
kubectl wait --for=condition=Ready pod/fortune --timeout=120s
kubectl exec fortune -c web-server -- stat -c '%y' /usr/share/nginx/html/index.html
# The file is new: its time is the start of the new Pod.

########################################################
# Step 3 - gitRepo is deprecated: an init container clones (slide 6)
########################################################
# The init container clones a repository into an
# emptyDir. Then nginx starts and serves it.
cat > gitrepo-volume-pod.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: gitrepo-volume-pod
spec:
  initContainers:
  - name: git-clone
    image: maziar/alpine-git
    args:
    - clone
    - --branch=master
    - https://github.com/sojoudian/kubia.git
    - /repo
    volumeMounts:
    - {name: html, mountPath: /repo}
  containers:
  - image: nginx:alpine
    name: web-server
    volumeMounts:
    - name: html
      mountPath: /usr/share/nginx/html
      readOnly: true
  volumes:
  - name: html
    emptyDir: {}
EOF
kubectl apply -f gitrepo-volume-pod.yaml
kubectl wait --for=condition=Ready pod/gitrepo-volume-pod --timeout=120s
kubectl logs gitrepo-volume-pod -c git-clone

# nginx serves the files of the repository.
GIT_IP=$(kubectl get pod gitrepo-volume-pod \
    -o jsonpath='{.status.podIP}')
curl -s http://$GIT_IP/app.js | head -5

########################################################
# Step 4 - hostPath keeps data on one node      (slide 7)
########################################################
# A hostPath volume is a folder of the node.
cat > hostpath-pod.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: hostpath-pod
spec:
  nodeSelector:
    kubernetes.io/hostname: workernode1
  containers:
  - name: shell
    image: busybox:1.36
    command: ["sleep", "3600"]
    volumeMounts:
    - name: node-data
      mountPath: /data
  volumes:
  - name: node-data
    hostPath:
      path: /tmp/clo835-week07
      type: DirectoryOrCreate
EOF
kubectl apply -f hostpath-pod.yaml
kubectl wait --for=condition=Ready pod/hostpath-pod --timeout=60s
kubectl exec hostpath-pod -- sh -c 'date > /data/note.txt'

# Delete the Pod and start it again on the same node.
kubectl delete pod hostpath-pod --now
kubectl apply -f hostpath-pod.yaml
kubectl wait --for=condition=Ready pod/hostpath-pod --timeout=60s
kubectl exec hostpath-pod -- cat /data/note.txt
# The file outlived the Pod. It stays on workernode1.

########################################################
# Step 5 - A PersistentVolumeClaim and a StorageClass (slide 8)
########################################################
# No cloud driver here, so install the
# local-path provisioner of the course repository.
REPO=https://raw.githubusercontent.com/sojoudian/CLO835_Fall_2026/master
kubectl apply -f $REPO/Week07/local-path-storage.yaml
kubectl get storageclass          # standard (default)

# The claim and a Pod that uses it.
cat > my-claim.yaml <<'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-claim
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: standard
  resources:
    requests: {storage: 1Gi}
---
apiVersion: v1
kind: Pod
metadata:
  name: pod-using-my-claim
spec:
  containers:
  - name: shell
    image: busybox:1.36
    command: ["sleep", "3600"]
    volumeMounts:
    - {name: my-volume, mountPath: /my-data}
  volumes:
  - name: my-volume
    persistentVolumeClaim:
      claimName: my-claim
EOF
kubectl apply -f my-claim.yaml
kubectl wait --for=condition=Ready pod/pod-using-my-claim --timeout=180s
kubectl get pvc,pv                # Bound, and a new PV

kubectl exec pod-using-my-claim -- sh -c 'echo kept > /my-data/note.txt'
kubectl exec pod-using-my-claim -- cat /my-data/note.txt

########################################################
# Step 6 - Clean up                             (slide 9)
########################################################
# ON THE MASTER - remove the Kubernetes objects.
bash cleanup_lab07.sh

# Confirm that nothing is left.
kubectl get pods,pvc,pv

# ON YOUR OWN MACHINE - remove the three EC2 machines.
# ON YOUR OWN MACHINE:  terraform destroy          # asks for key_name again

# Always destroy. The Learner Lab budget is small.
