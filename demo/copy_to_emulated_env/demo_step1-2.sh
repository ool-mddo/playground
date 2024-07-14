#!/usr/bin/bash

# shellcheck disable=SC1091
source ./demo_vars

if use_bgp_proc "$NETWORK_NAME" original_asis ; then
  echo "Network:$NETWORK_NAME uses BGP, expand external-AS network and splice it into topology data"
else
  echo "Network:$NETWORK_NAME does not use BGP (Nothing to do in step1-2)"
  exit 0
fi

# bgp-policy data handling
# parse configuration files with TTP
curl -s -X POST -H "Content-Type: application/json" \
  -d '{}' \
  "http://${API_PROXY}/bgp_policy/${NETWORK_NAME}/original_asis/parsed_result"

# post bgp policy data to model-conductor to merge it with topology data
curl -s -X POST -H "Content-Type: application/json" \
  -d '{}' \
  "http://${API_PROXY}/bgp_policy/${NETWORK_NAME}/original_asis/topology"

# generate external-AS topology
external_as_topology_dir="${USECASE_COMMON_DIR}/external_as_topology"
if [ ! -e "$external_as_topology_dir" ]; then
  external_as_topology_dir="${USECASE_DIR}/external_as_topology"
fi
external_as_script="${external_as_topology_dir}/main.rb"
external_as_json="${USECASE_CONFIGS_DIR}/external_as_topology.json"
params_file="${USECASE_DIR}/params.yaml"
flowdata_file="${USECASE_DIR}/flowdata.csv"
ruby "$external_as_script" -n "$NETWORK_NAME" -p "$params_file" -f "$flowdata_file"  > "$external_as_json"
# splice external-AS topology to original_asis (overwrite)
curl -s -X POST -H "Content-Type: application/json" \
  -d @<(jq '{ "overwrite": true, "ext_topology_data": . }' "$external_as_json") \
  "http://${API_PROXY}/conduct/${NETWORK_NAME}/original_asis/splice_topology" \
  > /dev/null # ignore echo-back (topology json)
