#!/bin/bash
# CLO835 - Week 03 - Docker networking, storage and security.
# Run these ON YOUR OWN LAPTOP, section by section. Docker must be running.
# Do NOT run the whole file at once.

########################################################
# Step 1 - Create a user-defined network
########################################################
# 1. create the network
docker network create \
    --driver bridge \
    --subnet 172.28.0.0/16 \
    clo835-net

# 2. confirm it exists
docker network ls | grep clo835

# 3. inspect - note the IPAM range and the empty Containers map
docker network inspect clo835-net

########################################################
# Step 2 - MySQL on the network, backed by a volume
########################################################
# 1. create the named volume (explicit is better)
docker volume create mysql-data

# 2. start MySQL on the network, with the volume
docker run -d \
    --name mysql-db \
    --network clo835-net \
    -e MYSQL_ROOT_PASSWORD=db_clo835 \
    --mount type=volume,source=mysql-data,target=/var/lib/mysql \
    mysql:8

# MySQL needs about 10 seconds before it accepts connections.
sleep 15

# 3. seed one row - proof that data lives on the volume
docker exec mysql-db \
    mysql -uroot -pdb_clo835 --table -e "
       CREATE DATABASE foo;
       USE foo;
       CREATE TABLE pets(name VARCHAR(20));
       INSERT INTO pets VALUES('Puffball');
       SELECT * FROM pets;"

docker ps --format '{{.Names}}\t{{.Status}}'
docker volume ls

########################################################
# Step 3 - Connect a web UI by container name
########################################################
# 1. start Adminer on clo835-net, publish port 8080
docker run -d \
    --name adminer \
    --network clo835-net \
    -p 8080:8080 \
    adminer:latest

# 2. prove DNS works from inside the network
docker run --rm \
    --network clo835-net \
    alpine nslookup mysql-db

# 3. open the Adminer UI
#    Browser -> http://localhost:8080
#      System:   MySQL
#      Server:   mysql-db        <- BY NAME, not IP
#      Username: root
#      Password: db_clo835
#      Database: foo

########################################################
# Step 4 - Now harden it
########################################################
# 1. IMAGE - scan for vulnerabilities
docker scout cves mysql:8
#    (or, if docker scout is not available:)
docker run --rm aquasec/trivy:latest image --scanners vuln mysql:8

# 2. SECRETS - keep the password OFF the command line
echo 'db_clo835' > ./db_password.txt
chmod 600 ./db_password.txt

# 3. RUNTIME - restart MySQL hardened (bind mount now)
docker rm -f mysql-db
mkdir -p $PWD/mysql-data
docker run -d \
    --name mysql-db \
    --network clo835-net \
    --mount type=bind,source=$PWD/mysql-data,target=/var/lib/mysql \
    --mount type=bind,source=$PWD/db_password.txt,target=/run/secrets/db_password,readonly \
    -e MYSQL_ROOT_PASSWORD_FILE=/run/secrets/db_password \
    --cap-drop=ALL \
    --cap-add=CHOWN \
    --cap-add=SETGID \
    --cap-add=SETUID \
    --cap-add=DAC_OVERRIDE \
    --cap-add=FOWNER \
    --security-opt=no-new-privileges \
    mysql:8

sleep 15

########################################################
# Step 5 - Check what happened to the row
########################################################
# stack is healthy?
docker ps --filter network=clo835-net

# did the row come back? (no 2>/dev/null - we want to SEE any error)
docker exec mysql-db bash -c \
    'mysql -uroot \
     -p"$(cat /run/secrets/db_password)" \
     -e "USE foo; SELECT * FROM pets;"'

# ERROR 1049 (42000): Unknown database 'foo'
# Puffball isn't here. Why? (Reflection 5)
#   Step 2 wrote it to the NAMED VOLUME mysql-data.
#   Step 4 switched to a BIND MOUNT, so MySQL started an empty database.

########################################################
# Step 6 - Clean up
########################################################
./cleanup_lab03.sh
