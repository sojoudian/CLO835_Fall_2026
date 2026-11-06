#!/bin/bash
# CLO835 - Lab 5 - remove everything the lab creates inside the cluster.
# The three machines are removed by "terraform destroy" on your own laptop.
set -uo pipefail

kubectl delete service nginx-http 2>/dev/null
kubectl delete rs kubia-rs 2>/dev/null
kubectl delete pod nginx kubia pingpong web-with-sidecar 2>/dev/null
kubectl delete namespace pingpong 2>/dev/null
rm -f ./kubia-manual.yaml ./sidecar.yaml ./rs.yaml

kubectl get deploy,rs,svc,pods --all-namespaces | grep -E "nginx|kubia|pingpong"

echo "done"
