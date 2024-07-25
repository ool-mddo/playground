#!/usr/bin/bash

# shellcheck disable=SC1091
source ./demo_vars

print_usage() {
  echo "Usage: $(basename "$0") [options]"
  echo "Options:"
  echo "  -d     Debug/data check, without executing ansible-runner (clab)"
  echo "  -h     Display this help message"
}

# option check
# defaults
WITH_CLAB=true
while getopts dh option; do
  case $option in
  d)
    # data check, debug
    # -> without container lab; does not build emulated-env
    WITH_CLAB=false
    echo "# Check: with_clab = $WITH_CLAB"
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

original_candidate_list="${USECASE_CONFIGS_DIR}/original_candidate_list.json"
for original_candidate_snapshot in $(jq -r ".[] | .snapshot" "$original_candidate_list")
do
  emulated_candidate_snapshot="${original_candidate_snapshot/original/emulated}"
  echo "Target snapshot: $emulated_candidate_snapshot"

  # set network name into namespace-relabeler
  echo "# TODO: push network/snapshot info into namespace-relabeler"
  # curl -s -X POST -H 'Content-Type: application/json' \
  #   -d '{"network_name": "'"$NETWORK_NAME"'"}' \
  #   http://localhost:15000/relabel/network

  # generate emulated_candidate environment from emulated_candidate topology/configs
  echo "# TODO: exec ansible to generate $emulated_candidate_snapshot clab env"
  # ansible-runner run . -p "/data/project/playbooks/step2-2.yaml" \
  #   --container-option="--net=${API_BRIDGE}" \
  #   --container-image="${ANSIBLE_RUNNER_IMAGE}" \
  #   --container-volume-mount="$PWD:/data" \
  #   --process-isolation \
  #   --process-isolation-executable docker \
  #   --cmdline "-e ansible_runner_dir=${ANSIBLE_RUNNER_DIR} \
  #             -e login_user=${LOCALSERVER_USER} \
  #             -e network_name=${NETWORK_NAME} \
  #             -e usecase_name=${USECASE_NAME} \
  #             -e usecase_common_name=${USECASE_COMMON_NAME} \
  #             -e with_clab=${WITH_CLAB} \
  #             -e clab_restart=${CLAB_RESTART} \
  #             -k -K"

  # stop/clean-up emulated env (need sudo)
  sudo ./demo_remove.sh
done
