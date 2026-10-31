#!/bin/bash
# CLO835 - Lab Week 09 - remove everything the lab creates inside the cluster.
# The three machines are removed by "terraform destroy" on your own laptop.
set -uo pipefail

kubectl delete deployment kubia 2>/dev/null
kubectl delete pod no-scheduler --now 2>/dev/null
kubectl uncordon workernode2 2>/dev/null
if [ -f /tmp/kube-scheduler.yaml ]; then sudo mv /tmp/kube-scheduler.yaml /etc/kubernetes/manifests/; fi

kubectl get pods,deployments | grep -E "kubia|no-scheduler"

echo "done"
