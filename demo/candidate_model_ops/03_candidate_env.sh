#!/usr/bin/bash

# shellcheck disable=SC1091
source ./demo_vars
IFS=',' read -r -a remotenode <<< $WORKER_ADDRESS
# shellcheck disable=SC1091
source ./up_emulated_env.sh

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

# cache sudo credential
echo "Please enter your sudo password:"
sudo -v

# at first: prepare each emulated_candidate topology data
original_candidate_list="${USECASE_SESSION_DIR}/original_candidate_list.json"
for target_original_snapshot in $(jq -r ".[] | .snapshot" "$original_candidate_list")
do
  # convert namespace from original_candidate_i to emulated_candidate_i
  convert_namespace "$target_original_snapshot"
done

# update netoviz index
netoviz_asis_index="${USECASE_SESSION_DIR}/netoviz_asis_index.json"
netoviz_original_candidates_index="${USECASE_SESSION_DIR}/netoviz_original_candidates_index.json"
netoviz_emulated_candidate_index="${USECASE_SESSION_DIR}/netoviz_emulated_candidate_index.json"
filter='map(.snapshot |= sub("original"; "emulated") | . + {label: ("MDDO-BGP (" + .snapshot + ")"), file: "topology.json"})'
jq "$filter" "$original_candidate_list" > "$netoviz_emulated_candidate_index"
netoviz_index="${USECASE_SESSION_DIR}/netoviz_index.json"
jq -s '.[0] + .[1] + .[2]' "$netoviz_asis_index" "$netoviz_original_candidates_index" "$netoviz_emulated_candidate_index" \
  > "$netoviz_index"

curl -s -X POST -H 'Content-Type: application/json' \
  -d @<(jq '{ "index_data": . }' "$netoviz_index") \
  "http://${API_PROXY}/topologies/index"

# up each emulated env
loopindex=1
for target_original_snapshot in $(jq -r ".[] | .snapshot" "$original_candidate_list")
do
  if [ ${#remotenode[@]} -eq 1 ]; then
    up_emulated_env "$target_original_snapshot" "$remotenode"
    let loopindex++
  else
    nodeindex=$((${loopindex}%${#remotenode[@]}))
    up_emulated_env "$target_original_snapshot" "${remotenode[$nodeindex]}"
    let loopindex++
  fi
done
