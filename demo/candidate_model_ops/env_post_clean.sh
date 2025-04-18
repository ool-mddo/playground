#!/usr/bin/bash

# cache sudo credential
echo "Please enter your sudo password:"
sudo -v

# shellcheck disable=SC1091
source ./demo_vars

# params
snapshot_name=$1
worker_node_address=$2

# delete containers related to containerlab
# delete ovs bridges
curl -s -X POST -H 'Content-Type: application/json' \
  -d '{
        "message": "destroy",
        "crpd_image": "'"$CRPD_IMAGE"'",
        "network_name": "'"$NETWORK_NAME"'",
        "usecase_name": "'"$USECASE_NAME"'",
        "remote_address": "'"$CONTROLLER_ADDRESS"'",
        "snapshot_name": "'"$snapshot_name"'"
      }' \
  "http://${worker_node_address}:$WORKER_PORT/endpoint"
