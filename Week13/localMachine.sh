#!/bin/bash
# CLO835 - Week 13 - Authentication and RBAC.
# Run these ON THE MASTER NODE, section by section. Do NOT run the whole file.
#
# Terraform builds 3 machines: 1 control plane and 2 workers. The cluster forms
# itself at boot, the same way it did in Weeks 04 to 12. Every object of the lab
# lives in the namespace week13.
#
# Each step matches one slide of Lab_week13_v2.pptx.

########################################################
# Step 0 - check the cluster                    (slide 3)
########################################################
# All three nodes must reach Ready. The workers take a few minutes to join.
kubectl get nodes -o wide
kubectl get pods -n kube-system

########################################################
# Step 1 - A new user is a signed certificate   (slide 4)
########################################################
# You are kubernetes-admin: a certificate with O = kubeadm:cluster-admins.
kubectl auth whoami

# The cluster CA signs a certificate for dev-user,
# group developers. Kubernetes stores no users.
openssl genrsa -out dev-user.key 2048
openssl req -new -key dev-user.key -out dev-user.csr -subj "/CN=dev-user/O=developers"
# No quotes on EOF: the shell puts the request in.
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

########################################################
# Step 2 - Authenticated, not authorized        (slide 5)
########################################################
kubectl create namespace week13
kubectl config set-credentials dev-user --client-certificate=dev-user.crt --client-key=dev-user.key --embed-certs=true
kubectl config set-context dev-user@kubernetes --cluster=kubernetes --user=dev-user --namespace=week13
kubectl config get-contexts

# The API knows who dev-user is:
kubectl --context=dev-user@kubernetes auth whoami

# ... but RBAC allows nothing yet:
kubectl --context=dev-user@kubernetes get pods
# Error from server (Forbidden): pods is forbidden: User "dev-user" cannot list resource "pods" ...

########################################################
# Step 3 - A Role and a RoleBinding for dev-user (slide 6)
########################################################
# The Role says what. The RoleBinding says who.
# RBAC needs the plural name: configmaps.
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

kubectl --context=dev-user@kubernetes run web --image=maziar/kubia:v1    # yes
kubectl --context=dev-user@kubernetes get pods                           # yes
kubectl --context=dev-user@kubernetes delete pod web                     # Forbidden

# An admin can ask on behalf of any user:
kubectl auth can-i delete pods -n week13 --as=dev-user
kubectl auth can-i --list -n week13 --as=dev-user

########################################################
# Step 4 - A Pod calls the API with its token   (slide 7)
########################################################
# A Pod runs as a ServiceAccount. Its token is
# mounted in the Pod.
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
# who the Pod is. RBAC allows nothing yet.

########################################################
# Step 5 - A Role for the ServiceAccount        (slide 8)
########################################################
# get and list Services, for the ServiceAccount clo835.
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

# The same call now returns a ServiceList.
kubectl exec curl-sa -n week13 -- sh -c 'SA=/var/run/secrets/kubernetes.io/serviceaccount; \
    curl -s --cacert $SA/ca.crt -H "Authorization: Bearer $(cat $SA/token)" \
    https://kubernetes.default.svc/api/v1/namespaces/week13/services | head -12; echo'

# A Role and its RoleBinding work in one namespace only.
kubectl auth can-i list services -n week13 --as=system:serviceaccount:week13:clo835
kubectl auth can-i list services -n default --as=system:serviceaccount:week13:clo835

########################################################
# Step 6 - Clean up                             (slide 9)
########################################################
# ON THE MASTER - remove the Kubernetes objects and the user.
bash cleanup_lab13.sh

# Confirm that nothing is left.
kubectl config get-contexts

# ON YOUR OWN MACHINE - remove the three EC2 machines.
# ON YOUR OWN MACHINE:  terraform destroy          # asks for key_name again

# Always destroy. The Learner Lab budget is small.
