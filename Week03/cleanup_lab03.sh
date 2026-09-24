#!/bin/bash
# CLO835 - Lab 3 - remove everything the lab creates.
set -uo pipefail

docker rm -f mysql-db adminer 2>/dev/null
docker rm -f $(docker ps -aq --filter network=clo835-net) 2>/dev/null
docker network rm clo835-net 2>/dev/null
docker volume rm mysql-data 2>/dev/null
docker rmi -f mysql:8 adminer:latest alpine:latest aquasec/trivy:latest 2>/dev/null

rm -rf ./mysql-data 2>/dev/null || sudo rm -rf ./mysql-data
rm -f ./db_password.txt

echo "done"
