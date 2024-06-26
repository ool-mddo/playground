#!/usr/bin/bash

### containerlab server login & sudo password Setting
###Example
###$ cat env/passwords 
###---
###"^SSH password:\\s*?$": "login password"
###"^BECOME password.*:\\s*?$": "login password"

# shellcheck disable=SC1091
source ./demo_vars

# save configs from emulated env containers
ansible-runner run . -p /data/project/playbooks/step3.yaml --container-option="--net=${API_BRIDGE}" \
  --container-volume-mount="$PWD:/data" --container-image="${ANSIBLE_RUNNER_IMAGE}" \
  --process-isolation --process-isolation-executable docker \
  --cmdline "-e ansible_runner_dir=${ANSIBLE_RUNNER_DIR} -e login_user=${LOCALSERVER_USER} -e network_name=${NETWORK_NAME} -k -K " -vvvv

# save emulated_asis layer3 topology as emulated_tobe layer1 topology
TEXT=$(jq -c . <(curl -s "http://${API_PROXY}/topologies/${NETWORK_NAME}/emulated_asis/topology/layer3/batfish_layer1_topology"))
curl -s -X POST -H 'Content-Type: application/json' \
  -d @<(jq -nc --arg text "$TEXT" '[{"filename": "layer1_topology.json", "text": $text }]') \
  "http://${API_PROXY}/configs/${NETWORK_NAME}/emulated_tobe/"

# generate emulated_tobe topology from saved (emulated_tobe) config
curl -s -X POST -H 'Content-Type: application/json' \
  -d '{ "label": "OSPF model (emulated_tobe)", "phy_ss_only": true }' \
  "http://${API_PROXY}/conduct/${NETWORK_NAME}/emulated_tobe/topology"

# generate model-based diff between emulated_asis and emulated_tobe and overwrite it to emulated_tobe
curl -s -X POST -H 'Content-Type: application/json' \
  -d '{ "upper_layer3": true }' \
  "http://${API_PROXY}/conduct/${NETWORK_NAME}/snapshot_diff/emulated_asis/emulated_tobe"

# update netoviz index
curl -s -X POST -H 'Content-Type: application/json' \
  -d @<(jq '{ "index_data": .[0:3] }' "$NETWORK_INDEX") \
  "http://${API_PROXY}/topologies/index"
