#!/usr/bin/bash

### containerlab server login & sudo password Setting
###Example
###$ cat env/passwords
###---
###"^SSH password:\\s*?$": "login password"
###"^BECOME password.*:\\s*?$": "login password"

# shellcheck disable=SC1091
source ./demo_vars

# option check
while getopts d option; do
  case $option in
  d)
    # data check, debug
    # -> without container lab; does not build emulated-env
    WITH_CLAB=false
    echo "# Check: with_clab = $WITH_CLAB"
    ;;
  *)
    echo "Unknown option detected, $option"
    exit 1
  esac
done

# convert namespace from original asis topology to emulated asis
curl -s -X POST -H 'Content-Type: application/json' \
  -d '{ "table_origin": "original_asis" }' \
  "http://${API_PROXY}/conduct/${NETWORK_NAME}/ns_convert/original_asis/emulated_asis"

# generate emulated asis configs from emulated asis topology
if "${WITH_CLAB:-true}"; then
  ansible-runner run . -p /data/project/playbooks/step2-1.yaml --container-option="--net=${API_BRIDGE}" \
    --container-volume-mount="$PWD:/data" --container-image="${ANSIBLERUNNER_IMAGE}" \
    --process-isolation --process-isolation-executable docker \
    --cmdline "-e ansible_runner_dir=${ANSIBLE_RUNNER_DIR} -e login_user=${LOCALSERVER_USER} -e network_name=${NETWORK_NAME} -e crpd_image=${CRPD_IMAGE} -k -K "
fi

# update netoviz index
curl -s -X POST -H 'Content-Type: application/json' \
  -d @<(jq '{ "index_data": .[0:2] }' "$NETWORK_INDEX" ) \
  "http://${API_PROXY}/topologies/index"
