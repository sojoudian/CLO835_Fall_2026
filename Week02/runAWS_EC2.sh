#!/bin/bash
# CLO835 - Week 02 - PART 1: the manual way.
# Run these ON THE EC2 MACHINE, section by section. Do NOT run the whole file.
#
# The machine has git and nothing else. You install the rest by hand.
# Count the steps. Part 2 shows the same steps inside a Dockerfile.

########################################################
# 1) Clone
########################################################
git clone https://github.com/sojoudian/simple-webapp-flask
cd simple-webapp-flask
ls -l                                # app.py  Dockerfile  requirements.txt

########################################################
# 2) Install Python
########################################################
sudo apt-get update -y
sudo apt-get install -y python3 python3-venv
python3 --version                    # 3.14.4 on Ubuntu 26.04

########################################################
# 3) Try the old way - it FAILS twice
########################################################
pip3 install flask
# Command 'pip3' not found. Ubuntu 26.04 ships no pip at all.
#
# Install it, then try again:
sudo apt-get install -y python3-pip
pip3 install flask
# error: externally-managed-environment
# Ubuntu 24.04 and later protect the system Python (PEP 668).

########################################################
# 4) Install Flask - the correct way
########################################################
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt      # Flask==3.1.3

########################################################
# 5) Run
########################################################
python3 app.py                       # app.py uses 8080 when PORT is not set

########################################################
# 6) Test
########################################################
# From a second SSH session:
curl http://localhost:8080/          # Welcome CLO835!
# From your browser, with the public_ip output of Terraform:
#   http://<PUBLIC-IP>:8080/

########################################################
# 7) Ask the class
########################################################
# - How do you repeat these 6 steps on a second machine?
# - How do you move this result to another computer?
# - What stays on the machine after you stop the app?
# - What breaks on a different Ubuntu version?
#
# Now go to localMachine.sh.
