### containerlab server login & sudo password Setting
###Example
###$ cat env/passwords 
###---
###"^SSH password:\\s*?$": "login password"
###"^BECOME password.*:\\s*?$": "login password"

source ./demo_vars

curl -s -X POST -H 'Content-Type: application/json' \
  -d '{ "table_origin": "original_asis" }' \
  http://localhost:15000/conduct/mddo-ospf/ns_convert/original_asis/emulated_asis

ansible-runner run . -p /data/project/playbooks/step02.yml --container-option="--net=${NODERED_BRIDGE}" \
	--container-volume-mount="$PWD:/data" --container-image=${ANSIBLERUNNER_IMAGE} \
       	--process-isolation --process-isolation-executable docker --cmdline  \
	"-e ansible_runner_dir=${ANSIBLE_RUNNER_DIR} -e labname=${LABNAME} -e login_user=${LOCALSERVER_USER} -e network_name=${NETWORK_NAME} -e demo_dir=${DEMO_DIR} -k -K " -vvvv                                                                  
