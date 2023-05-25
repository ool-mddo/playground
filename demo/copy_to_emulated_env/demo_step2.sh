#!/usr/bin/bash

### containerlab server login & sudo password Setting
###Example
###$ cat env/passwords 
###---
###"^SSH password:\\s*?$": "login password"
###"^BECOME password.*:\\s*?$": "login password"

# shellcheck disable=SC1091
source ./demo_vars

# convert namespace from original asis topology to emulated asis
curl -s -X POST -H 'Content-Type: application/json' \
  -d '{ "table_origin": "original_asis" }' \
  "http://${API_PROXY}/conduct/mddo-ospf/ns_convert/original_asis/emulated_asis"

# generate emulated asis configs from emulated asis topology
ansible-runner run . -p /data/project/playbooks/step2.yaml --container-option="--net=${API_BRIDGE}" \
  --container-volume-mount="$PWD:/data" --container-image="${ANSIBLERUNNER_IMAGE}" \
  --process-isolation --process-isolation-executable docker \
  --cmdline "-e ansible_runner_dir=${ANSIBLE_RUNNER_DIR} -e login_user=${LOCALSERVER_USER} -k -K " -vvvv

# update netoviz index
curl -s -X POST -H 'Content-Type: application/json' \
  -d @<(jq '{ "index_data": .[0:2] }' mddo_ospf_index.json ) \
  "http://${API_PROXY}/topologies/index"
