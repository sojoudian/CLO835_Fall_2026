#!/bin/bash
# CLO835 - Lab 4 - remove everything the lab creates inside the cluster.
# The three machines are removed by "terraform destroy" on your own laptop.
set -uo pipefail

kubectl delete deployment nginx-deploy 2>/dev/null
kubectl delete service nginx-http 2>/dev/null
kubectl delete pod nginx 2>/dev/null

kubectl get deploy,svc,pods

echo "done"
