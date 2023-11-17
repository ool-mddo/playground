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

# convert node/interface name (original to emulated)
EMULATE_PREFERRED_NODE=$(
  curl -s -X POST -H 'Content-Type: application/json' \
    -d "{ \"host_name\": \"${PREFERRED_NODE}\" }" \
    "http://${API_PROXY}/topologies/${NETWORK_NAME}/ns_convert_table/query" | jq -r .target_host.l3_model
)
EMULATE_PREFERRED_INTERFACE=$(
  curl -s -X POST -H 'Content-Type: application/json' \
    -d "{ \"host_name\": \"${EMULATE_PREFERRED_NODE}\", \"if_name\": \"${PREFERRED_INTERFACE}\" }" \
    "http://${API_PROXY}/topologies/${NETWORK_NAME}/ns_convert_table/query" | jq -r .target_if.l3_model
)

# set preferred peer
curl -s -X POST -H "Content-Type: application/json" \
  -d "{ \"ext_asn\": ${EXTERNAL_ASN}, \"node\": \"${PREFERRED_NODE}\", \"interface\": \"${EMULATE_PREFERRED_INTERFACE}\" }" \
  "http://${API_PROXY}/conduct/${NETWORK_NAME}/emulated_asis/topology/bgp_proc/preferred_peer" \
  > /dev/null # ignore echo-back (topology json)

# configure iperf client/server
if "${WITH_CLAB:-true}"; then
    ansible-runner run . -p /data/project/playbooks/step2.5.yaml --container-option="--net=${API_BRIDGE}" \
        --container-volume-mount="$PWD:/data" --container-image="${ANSIBLERUNNER_IMAGE}" \
        --process-isolation --process-isolation-executable docker \
        --cmdline "-e ansible_runner_dir=${ANSIBLE_RUNNER_DIR} -e login_user=${LOCALSERVER_USER} -e network_name=${NETWORK_NAME} -k -K "
fi
