#!/bin/bash
# CLO835 - Lab Week 12 - remove everything the lab creates inside the cluster.
# The three machines are removed by "terraform destroy" on your own laptop.
set -uo pipefail

kubectl delete namespace week12 week12-dev 2>/dev/null
rm -f ./fortune-args.yaml ./config-env.yaml ./config-volume.yaml ./secret-pod.yaml
rm -f ./config-dev.yaml ./LOG_LEVEL ./DB_Password

kubectl get namespaces | grep week12

echo "done"
