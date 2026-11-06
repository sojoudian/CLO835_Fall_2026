#!/bin/bash
# CLO835 - Week 14 - Kubeconfig and the Horizontal Pod Autoscaler.
# Run these ON THE MASTER NODE, section by section. Do NOT run the whole file.
#
# Terraform builds 3 machines: 1 control plane and 2 workers. The cluster forms
# itself at boot, the same way it did in Weeks 04 to 13.
#
# Each step matches one slide of Lab_week14_v2.pptx.

########################################################
# Step 0 - check the cluster                    (slide 3)
########################################################
# All three nodes must reach Ready. The workers take a few minutes to join.
kubectl get nodes -o wide
kubectl get pods -n kube-system

########################################################
# Step 1 - A second user: viewer                (slide 4)
########################################################
# kubectl reads ~/.kube/config: clusters, users, contexts.
kubectl config get-contexts

# The cluster CA signs a certificate for viewer, and the
# built-in ClusterRole view gives read-only access.
openssl genrsa -out viewer.key 2048
openssl req -new -key viewer.key -out viewer.csr -subj "/CN=viewer/O=viewers"
cat > viewer-csr.yaml <<EOF
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: viewer
spec:
  request: $(base64 -w0 < viewer.csr)
  signerName: kubernetes.io/kube-apiserver-client
  expirationSeconds: 86400
  usages:
  - client auth
EOF
kubectl apply -f viewer-csr.yaml
kubectl certificate approve viewer
kubectl get csr viewer                    # Approved,Issued
kubectl get csr viewer -o jsonpath='{.status.certificate}' | base64 -d > viewer.crt
kubectl create clusterrolebinding viewer-view --clusterrole=view --user=viewer

########################################################
# Step 2 - A context, and switch to it          (slide 5)
########################################################
# A context = one cluster + one user + a namespace.
kubectl config set-credentials viewer --client-certificate=viewer.crt --client-key=viewer.key --embed-certs=true
kubectl create namespace dev
kubectl config set-context context-1 --cluster=kubernetes --user=viewer --namespace=dev

# Switch: the cluster, the user AND the namespace change together.
kubectl config use-context context-1
kubectl config current-context                # context-1
kubectl get pods                              # allowed: No resources found in dev
kubectl create deployment web --image=maziar/kubia:v1     # Forbidden: view cannot create

# Back to the admin.
kubectl config use-context kubernetes-admin@kubernetes
kubectl config get-contexts

########################################################
# Step 3 - The Metrics Server                   (slide 6)
########################################################
# The HPA reads the CPU use from the Metrics Server. Install it from the course repository.
# This copy adds --kubelet-insecure-tls: a kubeadm kubelet serves a self-signed certificate.
kubectl apply -f https://raw.githubusercontent.com/sojoudian/CLO835_Fall_2026/master/Week14/metrics-server.yaml
kubectl -n kube-system rollout status deployment/metrics-server
kubectl wait --for=condition=Available apiservice/v1beta1.metrics.k8s.io --timeout=180s
kubectl get apiservice v1beta1.metrics.k8s.io           # AVAILABLE True
sleep 30; kubectl top nodes

########################################################
# Step 4 - A HorizontalPodAutoscaler            (slide 7)
########################################################
# A PHP page that burns CPU on every request.
kubectl create deployment php-apache --image=maziar/hpa-example
kubectl set resources deployment php-apache --requests=cpu=200m
kubectl expose deployment php-apache --port=80
kubectl rollout status deployment/php-apache

# Keep the average CPU at 50 % of the request.
cat > hpa.yaml <<'EOF'
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: php-apache
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: php-apache
  minReplicas: 1
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 50
EOF
kubectl apply -f hpa.yaml
# Wait for the first CPU sample. Before it, TARGETS is <unknown>.
kubectl wait --for=condition=ScalingActive hpa/php-apache --timeout=180s
kubectl get hpa php-apache
# TARGETS cpu: 0%/50%   REPLICAS 1

########################################################
# Step 5 - Generate load and watch the HPA scale (slide 8)
########################################################
# A Pod that calls the application in a loop.
kubectl run load-generator --image=busybox:1.36 --restart=Never -- /bin/sh -c "while sleep 0.01; do wget -q -O- http://php-apache; done"

# Read the HPA every 15 s for 3 minutes. REPLICAS climbs.
for i in $(seq 12); do kubectl get hpa php-apache --no-headers; sleep 15; done

# desired replicas = ceil( current replicas x current CPU / target CPU )
kubectl describe hpa php-apache | grep -A1 '^Metrics:'
kubectl get pods -l app=php-apache

# Stop the load. After the 5-minute stabilization window, the HPA scales down.
kubectl delete pod load-generator --now

########################################################
# Step 6 - Clean up                             (slide 9)
########################################################
# ON THE MASTER - remove the Kubernetes objects and the viewer user.
bash cleanup_lab14.sh

# Confirm that nothing is left.
kubectl get hpa,deployments,pods

# ON YOUR OWN MACHINE - remove the three EC2 machines.
# ON YOUR OWN MACHINE:  terraform destroy          # asks for key_name again

# Always destroy. The Learner Lab budget is small.
