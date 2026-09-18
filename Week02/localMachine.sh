#!/bin/bash
# CLO835 - Week 02 - PART 2: the container way.
# Run these ON YOUR OWN LAPTOP, section by section. Docker must be running.
#
# Part 1 took 6 manual steps on a machine. The Dockerfile holds the same steps,
# and one build repeats them anywhere.

########################################################
# 1) Clone
########################################################
git clone https://github.com/sojoudian/simple-webapp-flask
cd simple-webapp-flask

########################################################
# 2) Read the Dockerfile
########################################################
cat Dockerfile
#
#   FROM ubuntu:26.04              == the EC2 machine
#   RUN apt-get install python3 python3-venv   == Part 1, step 2
#   RUN python3 -m venv /opt/venv              == Part 1, step 4
#   RUN pip install -r requirements.txt        == Part 1, step 4
#   CMD ["python3", "app.py"]                  == Part 1, step 5
#
# The container runs the SAME command as the manual way.
# Only ENV PORT=18080 differs, so the container answers on 18080.

########################################################
# 3) Build
########################################################
docker build -t simple-webapp-flask:v1 .
docker images | grep simple-webapp-flask

########################################################
# 4) Run and test
########################################################
docker run -d --name webapp -p 18080:18080 simple-webapp-flask:v1
docker ps
curl http://localhost:18080/         # Welcome CLO835!
docker logs webapp

########################################################
# 5) Tag
########################################################
# Replace <user> with your Docker Hub account name.
docker tag simple-webapp-flask:v1 <user>/simple-webapp-flask:v1

########################################################
# 6) Publish
########################################################
docker login
docker push <user>/simple-webapp-flask:v1

########################################################
# 7) Prove the point
########################################################
# On the EC2 machine, or on ANY computer with Docker:
#   docker run -d -p 18080:18080 <user>/simple-webapp-flask:v1
# One command repeats all 6 steps of Part 1.

########################################################
# 8) Clean up
########################################################
docker rm -f webapp
terraform destroy                    # in the Week02 directory
