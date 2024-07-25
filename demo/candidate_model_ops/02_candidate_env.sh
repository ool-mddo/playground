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

# at first: prepare each emulated_candidate topology data
for original_candidate_snapshot in $(jq -r ".[] | .snapshot" "$original_candidate_list")
do
  # convert namespace from original_candidate_i to emulated_candidate_i
  emulated_candidate_snapshot="${original_candidate_snapshot/original/emulated}"
  echo "Convert to: $emulated_candidate_snapshot"
  curl -s -X POST -H 'Content-Type: application/json' \
    -d '{ "table_origin": "'"$original_candidate_snapshot"'" }' \
    "http://${API_PROXY}/conduct/${NETWORK_NAME}/ns_convert/original_asis/${emulated_candidate_snapshot}"
done

# update netoviz index
netoviz_original_asis_index="${USECASE_CONFIGS_DIR}/netoviz_original_asis_index.json"
netoviz_original_candidates_index="${USECASE_CONFIGS_DIR}/netoviz_original_candidates_index.json"
netoviz_emulated_candidate_index="${USECASE_CONFIGS_DIR}/netoviz_emulated_candidate_index.json"
filter='map(.snapshot |= sub("original"; "emulated") | . + {label: ("MDDO-BGP (" + .snapshot + ")"), file: "topology.json"})'
jq "$filter" "$original_candidate_list" > "$netoviz_emulated_candidate_index"
netoviz_index="${USECASE_CONFIGS_DIR}/netoviz_index.json"
jq -s '.[0] + .[1] + .[2]' "$netoviz_original_asis_index" "$netoviz_original_candidates_index" "$netoviz_emulated_candidate_index" \
  > "$netoviz_index"

curl -s -X POST -H 'Content-Type: application/json' \
  -d @<(jq '{ "index_data": . }' "$netoviz_index") \
  "http://${API_PROXY}/topologies/index"

# up each emulated env
for original_candidate_snapshot in $(jq -r ".[] | .snapshot" "$original_candidate_list")
do
  emulated_candidate_snapshot="${original_candidate_snapshot/original/emulated}"
  echo "Target snapshot: $emulated_candidate_snapshot"

  # generate emulated_candidate configs from emulated_candidate topology
  echo "# TODO: exec ansible to generate $emulated_candidate_snapshot"
  # ansible-runner run . -p /data/project/playbooks/step2-1.yaml \
  #   --container-option="--net=${API_BRIDGE}" \
  #   --container-image="${ANSIBLE_RUNNER_IMAGE}" \
  #   --container-volume-mount="$PWD:/data" \
  #   --process-isolation \
  #   --process-isolation-executable docker \
  #   --cmdline "-e ansible_runner_dir=${ANSIBLE_RUNNER_DIR} \
  #             -e login_user=${LOCALSERVER_USER} \
  #             -e network_name=${NETWORK_NAME} \
  #             -e crpd_image=${CRPD_IMAGE} \
  #             -e with_clab=${WITH_CLAB} \
  #             -k -K"

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
