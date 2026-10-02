#!/bin/bash
# CLO835 - Lab 4 - remove everything the lab creates.
set -uo pipefail

kubectl delete deployment nginx-deploy 2>/dev/null
kubectl delete service nginx-http 2>/dev/null
kubectl delete pod nginx 2>/dev/null
kind delete cluster --name kind 2>/dev/null

docker rm -f $(docker ps -aq) 2>/dev/null
docker rmi -f $(docker images -aq) 2>/dev/null

rm -f ./kind.yaml

echo "done"
