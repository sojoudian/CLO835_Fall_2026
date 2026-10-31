#!/bin/bash
# CLO835 - Lab 13 - remove everything the lab creates inside the cluster.
# The three machines are removed by "terraform destroy" on your own laptop.
set -uo pipefail

kubectl delete namespace week13 2>/dev/null
kubectl delete csr dev-user 2>/dev/null
kubectl config delete-context dev-user@kubernetes 2>/dev/null
kubectl config delete-user dev-user 2>/dev/null
rm -f ./dev-user.key ./dev-user.csr ./dev-user.crt ./dev-user-csr.yaml ./developer-role.yaml ./curl-sa.yaml ./service-reader.yaml

kubectl config get-contexts

echo "done"
