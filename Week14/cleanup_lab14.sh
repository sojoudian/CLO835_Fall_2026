#!/bin/bash
# CLO835 - Lab 14 - remove everything the lab creates inside the cluster.
# The three machines are removed by "terraform destroy" on your own laptop.
set -uo pipefail

kubectl config use-context kubernetes-admin@kubernetes 2>/dev/null
kubectl delete hpa php-apache 2>/dev/null
kubectl delete deployment php-apache 2>/dev/null
kubectl delete service php-apache 2>/dev/null
kubectl delete pod load-generator --now 2>/dev/null
kubectl delete namespace dev 2>/dev/null
kubectl delete clusterrolebinding viewer-view 2>/dev/null
kubectl delete csr viewer 2>/dev/null
kubectl config delete-context context-1 2>/dev/null
kubectl config delete-user viewer 2>/dev/null
kubectl -n kube-system delete deployment metrics-server 2>/dev/null
kubectl -n kube-system delete service metrics-server 2>/dev/null
kubectl delete apiservice v1beta1.metrics.k8s.io 2>/dev/null
kubectl -n kube-system delete serviceaccount metrics-server 2>/dev/null
kubectl -n kube-system delete rolebinding metrics-server-auth-reader 2>/dev/null
kubectl delete clusterrolebinding metrics-server:system:auth-delegator system:metrics-server 2>/dev/null
kubectl delete clusterrole system:aggregated-metrics-reader system:metrics-server 2>/dev/null
rm -f ./viewer.key ./viewer.csr ./viewer.crt ./viewer-csr.yaml ./hpa.yaml

kubectl get hpa,deployments,pods

echo "done"
