#!/usr/bin/bash

# cache sudo credential
echo "Please enter your sudo password:"
sudo -v

# shellcheck disable=SC1091
source ./demo_vars

# delete files and containers related to containerlab
sudo rm -f "${USECASE_CONFIGS_DIR}"/*.conf
sudo containerlab destroy --topo "${ANSIBLE_RUNNER_DIR}/clab/clab-topo.yaml" --cleanup
sudo rm -f "${ANSIBLE_RUNNER_DIR}/clab"/*.conf
sudo rm -f "${ANSIBLE_RUNNER_DIR}/clab/clab-topo.yaml"

# delete ovs bridges
curl -s "http://${API_PROXY}/topologies/${NETWORK_NAME}/emulated_asis/topology/layer3/nodes?node_type=segment" \
  | jq '.nodes[].alias.l1_principal' \
  | xargs -I@ sudo ovs-vsctl del-br @

