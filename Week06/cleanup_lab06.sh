#!/bin/bash
# CLO835 - Lab 6 - remove everything the lab creates inside the cluster.
# The three machines are removed by "terraform destroy" on your own laptop.
set -uo pipefail

kubectl delete service kubia kubia-nodeport 2>/dev/null
kubectl delete deployment kubia 2>/dev/null
kubectl delete pod client --now 2>/dev/null
kubectl delete pod -l app=kubia-debug --now 2>/dev/null
rm -f ./deployment.yaml ./service.yaml ./service-nodeport.yaml

kubectl get all | grep -E "kubia|client"

echo "done"
