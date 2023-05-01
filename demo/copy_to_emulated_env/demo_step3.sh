### containerlab server login & sudo password Setting
###Example
###$ cat env/passwords 
###---
###"^SSH password:\\s*?$": "login password"
###"^BECOME password.*:\\s*?$": "login password"

source ./demo_vars

# save configs from emulated env containers
ansible-runner run . -p /data/project/playbooks/step03.yml --container-option="--net=${NODERED_BRIDGE}" \
	--container-volume-mount="$PWD:/data" --container-image=${ANSIBLERUNNER_IMAGE} \
	--process-isolation --process-isolation-executable docker --cmdline \
	"-e ansible_runner_dir=${ANSIBLE_RUNNER_DIR} -e playground_dir=${PLAYGROUND_DIR} -e model_merge_dir=${MODEL_MERGE_DIR} -e nodered_url=${NODERED_URL} -e labname=${LABNAME} -e login_user=${LOCALSERVER_USER} -e netoviz_url=${NETOVIZ_URL} -e network_name=${NETWORK_NAME} -e demo_dir=${DEMO_DIR} -k -K " -vvvv

# generate emulated_tobe topology from save (emulated_tobe) config
# curl -s -X POST -H 'Content-Type: application/json' \
#   -d '{ "label": "OSPF model (emulated_tobe)", "phy_ss_only": true }' \
#   http://localhost:15000/conduct/mddo-ospf/emulated_tobe/topology

# generate model-based diff between emulated_asis and emulated_tobe and overwrite it to emulated_tobe
# curl -s -X POST -H 'Content-Type: application/json' \
#   -d '{ "upper_layer3": true }' \
#   http://localhost:15000/conduct/mddo-ospf/snapshot_diff/emulated_asis/emulated_tobe