source ../demo_vars
rm -f $ANSIBLE_RUNNER_DIR/project/playbooks/configs/*.conf
sudo containerlab destroy --topo $ANSIBLE_RUNNER_DIR/clab/clab-topo.yml --cleanup
sudo rm -f $ANSIBLE_RUNNER_DIR/clab/*.conf
sudo rm -f $ANSIBLE_RUNNER_DIR/clab/clab-topo.yml

# delete ovs bridges.
sudo ovs-vsctl list-br | xargs -I@ sudo ovs-vsctl del-br @
