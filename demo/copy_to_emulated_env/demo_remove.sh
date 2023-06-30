#!/usr/bin/bash

# check user id
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (sudo)"
  exit 1
fi

# shellcheck disable=SC1091
source ./demo_vars

# delete files and containers related to containerlab
rm -f "$ANSIBLE_RUNNER_DIR/project/playbooks/configs/"*.conf
sudo containerlab destroy --topo "$ANSIBLE_RUNNER_DIR/clab/clab-topo.yaml" --cleanup
sudo rm -f "$ANSIBLE_RUNNER_DIR/clab/"*.conf
sudo rm -f "$ANSIBLE_RUNNER_DIR/clab/clab-topo.yaml"

# delete ovs bridges
curl -s "http://localhost:15000/topologies/${NETWORK_NAME}/emulated_asis/topology/layer3/nodes?node_type=segment" \
  | jq '.nodes[].alias.l1_principal' \
  | xargs -I@ sudo ovs-vsctl del-br @
