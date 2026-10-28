#!/bin/bash
# CLO835 - Lab 7 - remove everything the lab creates inside the cluster.
# The three machines are removed by "terraform destroy" on your own laptop.
set -uo pipefail

kubectl delete pod fortune gitrepo-volume-pod hostpath-pod pod-using-my-claim --now 2>/dev/null
kubectl delete pvc my-claim 2>/dev/null
# The provisioner deletes the PV of the claim. Wait for that, then remove the provisioner.
for i in $(seq 30); do [ -z "$(kubectl get pv -o name)" ] && break; sleep 2; done
kubectl delete storageclass standard 2>/dev/null
kubectl delete namespace local-path-storage 2>/dev/null
kubectl delete clusterrolebinding local-path-provisioner-bind 2>/dev/null
kubectl delete clusterrole local-path-provisioner-role 2>/dev/null
rm -f ./fortune-pod.yaml ./gitrepo-volume-pod.yaml ./hostpath-pod.yaml ./my-claim.yaml

kubectl get pods,pvc,pv

echo "done"
