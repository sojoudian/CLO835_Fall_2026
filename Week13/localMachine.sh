#!/bin/bash
# CLO835 - Week 13 - Authentication and RBAC.
# Run the commands ON THE MASTER NODE, step by step, except the commands ON YOUR OWN MACHINE. Do NOT run the whole file.
#
# Terraform builds 3 EC2 instances: 1 master and 2 workers. The cluster forms
# itself at boot, as in Weeks 04 to 12. The objects that have a namespace are
# in the namespace week13.
#
# Each step matches one slide of Lab_week13_v5.pptx.

########################################################
# Step 0 - Build and check the cluster          (slide 3)
########################################################
# ON YOUR OWN MACHINE - get the repo. Then build 1 master and 2 workers.
# If no clone exists: git clone https://github.com/sojoudian/CLO835_Fall_2026.git
# git reset --hard replaces your changes with the files of GitHub.
# ON YOUR OWN MACHINE:  cd CLO835_Fall_2026 && git fetch && git reset --hard origin/master
# ON YOUR OWN MACHINE:  cd Week13 && terraform init
# ON YOUR OWN MACHINE:  terraform apply          # Terraform asks for key_name
# These two commands show the public and the private addresses.
# ON YOUR OWN MACHINE:  terraform output public_ips
# ON YOUR OWN MACHINE:  terraform output private_ips
# kubeadm forms the cluster at boot. Wait about 4 minutes.
# ON YOUR OWN MACHINE:  ssh -i <your-key>.pem ubuntu@<masternode-public-ip>
# ON THE MASTER - check the three nodes
kubectl get nodes -o wide
kubectl get pods -n kube-system

########################################################
# Step 1 - A new user is a signed certificate   (slide 4)
########################################################
# The cluster CA signs a certificate for dev-user. Kubernetes stores no users.
# CN is the user name. O is the group: developers.
openssl genrsa -out dev-user.key 2048
openssl req -new -key dev-user.key -out dev-user.csr -subj "/CN=dev-user/O=developers"
# EOF has no quotes, so the shell writes the base64 request into the file.
cat > dev-user-csr.yaml <<EOF
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: dev-user
spec:
  request: $(base64 -w0 < dev-user.csr)
  signerName: kubernetes.io/kube-apiserver-client
  expirationSeconds: 86400
  usages:
  - client auth
EOF
kubectl apply -f dev-user-csr.yaml
kubectl certificate approve dev-user
kubectl get csr dev-user                    # Approved,Issued
kubectl get csr dev-user -o jsonpath='{.status.certificate}' | base64 -d > dev-user.crt
openssl x509 -in dev-user.crt -noout -subject -enddate
# subject=O=developers, CN=dev-user
# The certificate is valid for 24 hours, because expirationSeconds is 86400.

########################################################
# Step 2 - Authenticated, not authorized        (slide 5)
########################################################
kubectl create namespace week13
kubectl config set-credentials dev-user --client-certificate=dev-user.crt --client-key=dev-user.key --embed-certs=true
kubectl config set-context dev-user@kubernetes --cluster=kubernetes --user=dev-user --namespace=week13

# With no credentials you are system:anonymous. Every client can read /version.
curl -k https://localhost:6443/version
curl -k https://localhost:6443/apis                # 403 Forbidden

# kubectl proxy sends your credentials to the API server, so this request passes.
kubectl proxy --port=8001 & sleep 2; curl -s http://localhost:8001/apis | head -8; kill %1
# The shell shows [1] and the process ID. The proxy shows Starting to serve on 127.0.0.1:8001.
# kill %1 stops the proxy. Then the shell shows [1]+ Terminated.

# Authentication: the API server knows who dev-user is. Every authenticated user can run auth whoami.
kubectl --context=dev-user@kubernetes auth whoami
# auth whoami shows dev-user, the groups developers and system:authenticated, and a hash of the certificate.

# Authorization: no Role allows dev-user to list Pods yet.
kubectl --context=dev-user@kubernetes get pods
# Error from server (Forbidden): pods is forbidden: User "dev-user" cannot list resource "pods" ...

########################################################
# Step 3 - A Role and a RoleBinding for dev-user (slide 6)
########################################################
# The Role says what. The RoleBinding says who.
# RBAC matches the name in the API path: configmaps, not ConfigMap.
cat > developer-role.yaml <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: developer
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["list", "get", "create", "update"]
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["create"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: devuser-developer-binding
subjects:
- kind: User
  name: dev-user
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: developer
  apiGroup: rbac.authorization.k8s.io
EOF
kubectl apply -f developer-role.yaml -n week13

kubectl --context=dev-user@kubernetes run web --image=maziar/kubia:v1    # pod/web created
kubectl --context=dev-user@kubernetes delete pod web                     # Forbidden

# The group of the certificate gets the default ClusterRole view.
kubectl create rolebinding developers-view --clusterrole=view --group=developers -n week13
kubectl --context=dev-user@kubernetes get services      # No resources found: allowed

########################################################
# Step 4 - A Pod calls the API with its token   (slide 7)
########################################################
# A Pod runs as a ServiceAccount. Kubernetes mounts
# its token in the Pod.
kubectl create serviceaccount clo835 -n week13
cat > curl-sa.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: curl-sa
spec:
  serviceAccountName: clo835
  containers:
  - name: main
    image: maziar/alpine-curl
    command: ["sleep", "3600"]
EOF
kubectl apply -f curl-sa.yaml -n week13
kubectl wait --for=condition=Ready pod/curl-sa -n week13 --timeout=120s

# Ask the API server for the Services of week13.
kubectl exec curl-sa -n week13 -- sh -c 'SA=/var/run/secrets/kubernetes.io/serviceaccount; \
    curl -s --cacert $SA/ca.crt -H "Authorization: Bearer $(cat $SA/token)" \
    https://kubernetes.default.svc/api/v1/namespaces/week13/services | head -12; echo'
# "reason": "Forbidden": the token proves
# who the Pod is. No Role allows it to list Services yet.

########################################################
# Step 5 - A Role and a ClusterRole for the ServiceAccount (slide 8)
########################################################
# The Role service-reader allows the ServiceAccount clo835 to get and list Services.
cat > service-reader.yaml <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: service-reader
rules:
- apiGroups: [""]
  resources: ["services"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: service-reader-binding
subjects:
- kind: ServiceAccount
  name: clo835
  namespace: week13
roleRef:
  kind: Role
  name: service-reader
  apiGroup: rbac.authorization.k8s.io
EOF
kubectl apply -f service-reader.yaml -n week13

# The same call now returns a ServiceList. week13 has no Service, so items is empty.
kubectl exec curl-sa -n week13 -- sh -c 'SA=/var/run/secrets/kubernetes.io/serviceaccount; \
    curl -s --cacert $SA/ca.crt -H "Authorization: Bearer $(cat $SA/token)" \
    https://kubernetes.default.svc/api/v1/namespaces/week13/services | head -12; echo'

# A Role and its RoleBinding work in one namespace only.
kubectl auth can-i list services -n default --as=system:serviceaccount:week13:clo835   # no

# A PersistentVolume has no namespace: NAMESPACED is false.
kubectl api-resources --sort-by name | grep -E 'NAMESPACED|persistentvolumes'
kubectl create clusterrole pv-reader --verb=get,list --resource=persistentvolumes
# A RoleBinding cannot give access to an object with no namespace.
kubectl create rolebinding pv-test --clusterrole=pv-reader --serviceaccount=week13:clo835 -n week13
kubectl auth can-i list persistentvolumes -A --as=system:serviceaccount:week13:clo835   # no
# A ClusterRoleBinding gives this access in the whole cluster.
kubectl create clusterrolebinding pv-test --clusterrole=pv-reader --serviceaccount=week13:clo835
kubectl auth can-i list persistentvolumes -A --as=system:serviceaccount:week13:clo835   # yes

########################################################
# Step 6 - Destroy the cluster                  (slide 9)
########################################################
# ON YOUR OWN MACHINE - destroy the three EC2 instances.
# This also deletes every Kubernetes object and every file of the lab.
# ON YOUR OWN MACHINE:  terraform destroy          # Terraform asks for key_name again

# Destroy the cluster at the end of each lab. The Learner Lab budget is small.
