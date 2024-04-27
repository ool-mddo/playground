#!/usr/bin/bash

### containerlab server login & sudo password Setting
###Example
###$ cat env/passwords
###---
###"^SSH password:\\s*?$": "login password"
###"^BECOME password.*:\\s*?$": "login password"

# shellcheck disable=SC1091
source ./demo_vars

print_usage() {
    echo "Usage: $(basename "$0") [options]"
    echo "Options:"
    echo "  -d     Debug/data check, without executing ansible-runner (clab)"
    echo "  -r     Restart containerlab"
    echo "  -h     Display this help message"
}

# option check
# defaults
WITH_CLAB=true
CLAB_RESTART=false
while getopts drh option; do
  case $option in
  d)
    # data check, debug
    # -> without container lab; does not build emulated-env
    WITH_CLAB=false
    echo "# Check: with_clab = $WITH_CLAB"
    ;;
  r)
    # restart clab/iperf
    CLAB_RESTART=true
    ;;
  h)
    print_usage
    exit 0
    ;;
  *)
    echo "Unknown option detected, -$OPTARG" >&2
    print_usage
    exit 1
    ;;
  esac
done

if [[ ! "$NETWORK_NAME" =~ $BGP_NETWORK_PATTERN ]]; then
  echo "Network:$NETWORK_NAME is not BGP network (Nothing to do in step2-2)"
  exit 0
else
  echo "# Network:$NETWORK_NAME is specified as BGP network, generate traffic between PNI and POI"
fi

# configure iperf client/server
if "${WITH_CLAB}"; then
  echo "# Check: clab_restart = $CLAB_RESTART"

  ansible-runner run . -p "/data/project/playbooks/step2-2.yaml" \
    --container-option="--net=${API_BRIDGE}" \
    --container-image="${ANSIBLE_RUNNER_IMAGE}" \
    --container-volume-mount="$PWD:/data" \
    --process-isolation \
    --process-isolation-executable docker \
    --cmdline "-e ansible_runner_dir=${ANSIBLE_RUNNER_DIR} \
               -e login_user=${LOCALSERVER_USER} \
               -e network_name=${NETWORK_NAME} \
               -e usecase_name=${USECASE_NAME} \
               -e usecase_common_name=${USECASE_COMMON_NAME} \
               -e clab_restart=${CLAB_RESTART} \
               -k -K"
fi
