#!/usr/bin/bash

# shellcheck disable=SC1091
source ./demo_vars
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

# at first: prepare emulated_asis topology data
target_original_snapshot="original_asis"
# convert namespace from original_asis to emulated_asis
convert_namespace "$target_original_snapshot"

# Add netoviz index
netoviz_asis_index="${USECASE_SESSION_DIR}/netoviz_asis_index.json"
jq '.[0:2]' "$NETWORK_INDEX" > "$netoviz_asis_index"
netoviz_original_candidates_index="${USECASE_SESSION_DIR}/netoviz_original_candidates_index.json"
netoviz_index="${USECASE_SESSION_DIR}/netoviz_index.json"
jq -s '.[0] + .[1]' "$netoviz_asis_index" "$netoviz_original_candidates_index" > "$netoviz_index"

curl -s -X POST -H 'Content-Type: application/json' \
  -d @<(jq '{ "index_data": . }' "$netoviz_index") \
  "http://${API_PROXY}/topologies/index"

# up original_asis env
up_emulated_env "$target_original_snapshot"
