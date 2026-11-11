#!/bin/bash
# CLO835 - Lab Week 12 - delete the objects and the files that the lab creates.
# On your own machine, "terraform destroy" destroys the three machines.
set -uo pipefail

kubectl delete namespace week12 week12-dev --ignore-not-found
rm -f ./fortune-args.yaml ./config-env.yaml ./config-volume.yaml ./secret-pod.yaml
rm -f ./config-dev.yaml ./LOG_LEVEL ./DB_Password

kubectl get namespaces | grep week12

echo "done"
