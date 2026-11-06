#!/bin/bash
# CLO835 - Lab Week 13 - delete everything that the lab creates inside the cluster.
# On your own machine, "terraform destroy" destroys the three EC2 instances.
set -uo pipefail

kubectl delete namespace week13 2>/dev/null
kubectl delete csr dev-user 2>/dev/null
kubectl delete clusterrolebinding pv-test 2>/dev/null
kubectl delete clusterrole pv-reader 2>/dev/null
kubectl config delete-context dev-user@kubernetes 2>/dev/null
kubectl config delete-user dev-user 2>/dev/null
rm -f ./dev-user.key ./dev-user.csr ./dev-user.crt ./dev-user-csr.yaml
rm -f ./developer-role.yaml ./curl-sa.yaml ./service-reader.yaml

kubectl config get-contexts

echo "done"
