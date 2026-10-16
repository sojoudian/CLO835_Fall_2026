#!/bin/bash
# CLO835 - Lab 6 - remove everything the lab creates inside the cluster.
# The three machines are removed by "terraform destroy" on your own laptop.
set -uo pipefail

kubectl delete ingress kubia 2>/dev/null
kubectl delete service kubia kubia-v2 kubia-nodeport kubia-lb 2>/dev/null
kubectl delete deployment kubia 2>/dev/null
kubectl delete pod kubia-manual kubia-manual-v2 client 2>/dev/null
kubectl delete pod -l app=kubia-debug 2>/dev/null
rm -f ./deployment.yaml ./pods-with-labels.yaml ./service.yaml ./service-nodeport.yaml ./ingress.yaml

kubectl get all,ingress | grep -E "kubia|client"

echo "done"
