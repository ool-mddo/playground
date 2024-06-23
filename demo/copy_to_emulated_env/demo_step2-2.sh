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

if use_bgp_proc "$NETWORK_NAME" original_asis ; then
  echo "Network:$NETWORK_NAME uses BGP, generate traffic between PNI and POI"
else
  echo "Network:$NETWORK_NAME does not use BGP (Nothing to do in step1-2)"
  exit 0
fi

# configure iperf client/server
echo "# Check: clab_restart = $CLAB_RESTART"

# set network name into namespace-relabeler
curl -s -X POST -H 'Content-Type: application/json' \
  -d '{"network_name": "'"$NETWORK_NAME"'"}' \
  http://localhost:15000/relabel/network

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
             -e with_clab=${WITH_CLAB} \
             -e clab_restart=${CLAB_RESTART} \
             -k -K"
