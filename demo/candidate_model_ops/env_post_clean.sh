#!/usr/bin/bash

# cache sudo credential
echo "Please enter your sudo password:"
sudo -v

# shellcheck disable=SC1091
source ./demo_vars

# delete containers related to containerlab
sudo containerlab destroy --topo "${ANSIBLE_RUNNER_DIR}/clab/clab-topo.yaml" --cleanup

# delete ovs bridges
curl -s "http://${API_PROXY}/topologies/${NETWORK_NAME}/emulated_asis/topology/layer3/nodes?node_type=segment" |
  jq '.nodes[].alias.l1_principal' |
  xargs -I@ sudo ovs-vsctl del-br @
