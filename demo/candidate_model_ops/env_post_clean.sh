#!/usr/bin/bash

# cache sudo credential
echo "Please enter your sudo password:"
sudo -v

# shellcheck disable=SC1091
source ./demo_vars

# delete containers related to containerlab
# delete ovs bridges
curl -H 'Content-Type: application/json' -d "{\"message\": \"destroy\",\"ansible_runner_dir\":\"${ANSIBLE_RUNNER_DIR}\",\"crpd_image\":\"${CRPD_IMAGE}\",\"network_name\":\"${NETWORK_NAME}\", \"usecase_name\": \"${USECASE_NAME}\", \"remote_address\": \"${CONTROLLER_ADDRESS}\", \"snapshot_name\":\"$1\"}" $2:48090/endpoint
