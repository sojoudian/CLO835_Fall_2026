#!/bin/bash
# CLO835 Week 02 - prereqs for the manual deployment VM.
#
# This installs git and NOTHING else, on purpose.
# No Docker. No pip. No Flask. No application.
# You install those by hand in runAWS_EC2.sh, and you count the steps.

set -eux
export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get install -y git

cat > /etc/motd <<'MOTD'

  CLO835 - Week 02 - The manual deployment VM
  -------------------------------------------
  This machine has git only. Nothing else is prepared.
  Follow runAWS_EC2.sh, section by section.

MOTD
