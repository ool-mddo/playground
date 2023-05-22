### containerlab server login & sudo password Setting
###Example
###$ cat env/passwords 
###---
###"^SSH password:\\s*?$": "login password"
###"^BECOME password.*:\\s*?$": "login password"

source ./demo_vars

# delete files and containers related to containerlab
rm -f $ANSIBLE_RUNNER_DIR/project/playbooks/configs/*.conf
sudo containerlab destroy --topo $ANSIBLE_RUNNER_DIR/clab/clab-topo.yaml --cleanup
sudo rm -f $ANSIBLE_RUNNER_DIR/clab/*.conf
sudo rm -f $ANSIBLE_RUNNER_DIR/clab/clab-topo.yaml

# delete ovs bridges
curl -s "http://localhost:15000/topologies/mddo-ospf/emulated_asis/topology/layer3/nodes?node_type=segment" \
     | jq '.[] | .alias.l1_principal' \
     | xargs -I@ sudo ovs-vsctl del-br @
