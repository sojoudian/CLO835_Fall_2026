#!/bin/bash
# CLO835 - Week 13 - Authentication and RBAC.
# Run these ON THE MASTER NODE, section by section. Do NOT run the whole file.
#
# Terraform builds 3 EC2 instances: 1 master and 2 workers. The cluster forms
# itself at boot, the same way it did in Weeks 04 to 12. The objects that have a
# namespace are in the namespace week13.
#
# Each step matches one slide of Lab_week13_v3.pptx.

########################################################
# Step 0 - check the cluster                    (slide 3)
########################################################
# All three nodes must reach Ready. The workers take a few minutes to join.
kubectl get nodes -o wide
kubectl get pods -n kube-system

########################################################
# Step 1 - A new user is a signed certificate   (slide 4)
########################################################
# The cluster CA signs a certificate for dev-user. Kubernetes stores no users.
# CN is the user name. O is the group: developers.
openssl genrsa -out dev-user.key 2048
openssl req -new -key dev-user.key -out dev-user.csr -subj "/CN=dev-user/O=developers"
# No quotes on EOF: the shell puts the request in.
# tee writes the file and shows it.
tee dev-user-csr.yaml <<EOF
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

# Authentication: the API knows who dev-user is. Every authenticated user can ask this.
kubectl --context=dev-user@kubernetes auth whoami

# Authorization: no Role lets dev-user list Pods yet.
kubectl --context=dev-user@kubernetes get pods
# Error from server (Forbidden): pods is forbidden: User "dev-user" cannot list resource "pods" ...

########################################################
# Step 3 - A Role and a RoleBinding for dev-user (slide 6)
########################################################
# The Role says what. The RoleBinding says who.
# RBAC matches the name in the API path: configmaps, not ConfigMap.
tee developer-role.yaml <<'EOF'
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
tee curl-sa.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: curl-sa
spec:
  serviceAccountName: clo835
  containers:
  - name: main
    image: maziar/curl
    command: ["sleep", "3600"]
EOF
kubectl apply -f curl-sa.yaml -n week13
kubectl wait --for=condition=Ready pod/curl-sa -n week13 --timeout=120s

# Ask the API server for the Services of week13.
kubectl exec curl-sa -n week13 -- sh -c 'SA=/var/run/secrets/kubernetes.io/serviceaccount; \
    curl -s --cacert $SA/ca.crt -H "Authorization: Bearer $(cat $SA/token)" \
    https://kubernetes.default.svc/api/v1/namespaces/week13/services | head -12; echo'
# "reason": "Forbidden": the token proves
# who the Pod is. No Role lets it list Services yet.

########################################################
# Step 5 - A Role and a ClusterRole for the ServiceAccount (slide 8)
########################################################
# get and list Services, for the ServiceAccount clo835.
tee service-reader.yaml <<'EOF'
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
# A RoleBinding does not grant access to a cluster-level resource.
kubectl create rolebinding pv-test --clusterrole=pv-reader --serviceaccount=week13:clo835 -n week13
kubectl auth can-i list persistentvolumes -A --as=system:serviceaccount:week13:clo835   # no
# A ClusterRoleBinding grants it.
kubectl create clusterrolebinding pv-test --clusterrole=pv-reader --serviceaccount=week13:clo835
kubectl auth can-i list persistentvolumes -A --as=system:serviceaccount:week13:clo835   # yes

########################################################
# Step 6 - Clean up                             (slide 9)
########################################################
# ON THE MASTER - delete the Kubernetes objects and the kubeconfig entry of dev-user.
# A CSR, a ClusterRole and a ClusterRoleBinding have no namespace,
# so the deletion of week13 does not delete them. The script deletes them one by one.
# The output must show the context kubernetes-admin@kubernetes only.
# This step takes about 40 seconds.
bash cleanup_lab13.sh

# ON YOUR OWN MACHINE - destroy the three EC2 instances.
# ON YOUR OWN MACHINE:  terraform destroy          # asks for key_name again

# Always destroy. The Learner Lab budget is small.
