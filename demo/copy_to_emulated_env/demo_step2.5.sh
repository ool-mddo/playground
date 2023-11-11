#!/usr/bin/bash

### containerlab server login & sudo password Setting
###Example
###$ cat env/passwords
###---
###"^SSH password:\\s*?$": "login password"
###"^BECOME password.*:\\s*?$": "login password"

# shellcheck disable=SC1091
source ./demo_vars

ansible-runner run . -p /data/project/playbooks/step2.5.yaml --container-option="--net=${API_BRIDGE}" \
    --container-volume-mount="$PWD:/data" --container-image="${ANSIBLERUNNER_IMAGE}" \
    --process-isolation --process-isolation-executable docker \
    --cmdline "-e ansible_runner_dir=${ANSIBLE_RUNNER_DIR} -e login_user=${LOCALSERVER_USER} -e network_name=${NETWORK_NAME} -k -K "
