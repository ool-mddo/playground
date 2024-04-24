#!/usr/bin/bash

### containerlab server login & sudo password Setting
###Example
###$ cat env/passwords
###---
###"^SSH password:\\s*?$": "login password"
###"^BECOME password.*:\\s*?$": "login password"

# shellcheck disable=SC1091
source ./demo_vars

if [[ ! "$NETWORK_NAME" =~ $BGP_NETWORK_PATTERN ]]; then
  echo "Network:$NETWORK_NAME is not BGP network (Nothing to do in step2-2)"
  exit 0
else
  echo "# Network:$NETWORK_NAME is specified as BGP network, generate traffic between PNI and POI"
fi

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

# configure iperf client/server
if "${WITH_CLAB:-true}"; then
  ansible-runner run . -p /data/project/playbooks/step2-2.yaml --container-option="--net=${API_BRIDGE}" \
    --container-volume-mount="$PWD:/data" --container-image="${ANSIBLE_RUNNER_IMAGE}" \
    --process-isolation --process-isolation-executable docker \
    --cmdline "-e ansible_runner_dir=${ANSIBLE_RUNNER_DIR} -e login_user=${LOCALSERVER_USER} -e network_name=${NETWORK_NAME} -e usecase_name=${USECASE_NAME} -e usecase_common_name=${USECASE_COMMON_NAME} -k -K "
fi
