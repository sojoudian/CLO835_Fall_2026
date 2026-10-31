#!/bin/bash
# CLO835 - Lab 10 - remove everything the lab creates inside the cluster.
# The three machines are removed by "terraform destroy" on your own laptop.
set -uo pipefail

pkill -f "kubectl proxy" 2>/dev/null
kubectl delete pod writer dnstest --now 2>/dev/null
kubectl delete statefulset kubia 2>/dev/null
kubectl delete service kubia 2>/dev/null
kubectl delete pvc data-pvc data-kubia-0 data-kubia-1 2>/dev/null
kubectl delete pv data-pv 2>/dev/null
# The provisioner deletes the PVs of the pets. Wait for that, then remove the provisioner.
for i in $(seq 30); do [ -z "$(kubectl get pv -o name)" ] && break; sleep 2; done
kubectl delete storageclass standard 2>/dev/null
kubectl delete namespace local-path-storage 2>/dev/null
kubectl delete clusterrolebinding local-path-provisioner-bind 2>/dev/null
kubectl delete clusterrole local-path-provisioner-role 2>/dev/null
rm -f ./pv-pvc.yaml ./writer.yaml ./kubia-statefulset.yaml

kubectl get pods,pvc,pv

echo "done"
