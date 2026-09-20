#!/usr/bin/bash

# shellcheck disable=SC1091
source ./util.sh

# output: original_asis topology (internal-AS only)
function generate_original_asis_topology() {
  curl -s -X DELETE "http://${API_PROXY}/conduct/${NETWORK_NAME}"
  curl -s -X POST -H 'Content-Type: application/json' \
    -d '{ "label": "original_asis", "phy_ss_only": true }' \
    "http://${API_PROXY}/conduct/${NETWORK_NAME}/original_asis/topology"
}

# output: original_asis topology (extended external-AS topology)
function splice_external_as_topology() {
  if ! use_bgp_proc original_asis; then
    return 0
  fi

  echo # newline
  echo "Network:$NETWORK_NAME uses BGP, expand external-AS network and splice it into topology data"

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
  external_as_json="${USECASE_SESSION_DIR}/external_as_topology.json"
  curl -s "http://${API_PROXY}/usecases/${USECASE_NAME}/${NETWORK_NAME}/original_asis/external_as_topology?flow_data=event" \
    >"$external_as_json"

  # splice external-AS topology to original_asis (overwrite)
  curl -s -X POST -H "Content-Type: application/json" \
    -d @<(jq '{ "overwrite": true, "ext_topology_data": . }' "$external_as_json") \
    "http://${API_PROXY}/conduct/${NETWORK_NAME}/original_asis/splice_topology" \
    >/dev/null # ignore echo-back (topology json)
}

# UNDER_DEVELOPMENT: parse firewall props and splice it original_asis topology
function splice_firewall_attributes() {
  # firewall-policy data handling

  # parse configuration files using TTP
  fw_params=$(get_usecase_params | jq -c '.cluster_firewall_pairs | {"cluster_firewall_pairs": .}')
  curl -s -X POST \
    -H 'Content-Type: application/json' \
    -d "${fw_params}" \
    http://${API_PROXY}/fw_policy/${NETWORK_NAME}/original_asis/parsed_result

  # post firewall policy data to model-conductor to merge it with topology data
  curl -s -X POST -H "Content-Type: application/json" \
    -d '{}' \
    "http://${API_PROXY}/fw_policy/${NETWORK_NAME}/original_asis/topology" \
    >/dev/null # ignore echo-back (topology json)
}

function copy_original_asis_to_preallocated() {
  curl -s "http://${API_PROXY}/topologies/${NETWORK_NAME}/original_asis/topology" | \
    jq '{ "topology_data": . }' - | \
    curl -s -X POST  -H "Content-Type: application/json" -d @- \
      "http://${API_PROXY}/topologies/${NETWORK_NAME}/original_asis_preallocated0/topology" \
    >/dev/null # ignore echo-back (topology json)
}

function splice_preallocated_resources() {
  # generate layer3 empty resources
  l3e_resources_json="${USECASE_SESSION_DIR}/layer3_preallocated_resources.json"
  curl -s "http://${API_PROXY}/usecases/${USECASE_NAME}/${NETWORK_NAME}/params/l3_preallocated_resources" \
    >"$l3e_resources_json"

  # splice pre-allocated resource topology to original_asis_preallocated (overwrite)
  curl -s -X POST -H "Content-Type: application/json" \
    -d @<(jq '{ "overwrite": true, "l3_preallocated_resources": . }' "$l3e_resources_json") \
    "http://${API_PROXY}/conduct/${NETWORK_NAME}/original_asis_preallocated0/splice_topology" \
    >/dev/null # ignore echo-back (topology json)
}

# output: original_candidate_xx topology
# output: original_candidate_list_x.json
function generate_original_candidate_topologies() {
  original_benchmark_topology=$1
  phase=$2
  candidate_num=$3

  original_candidate_list=$(original_candidate_list_path "$phase")

  curl -s -X POST -H 'Content-Type: application/json' \
    -d '{
      "phase_number": "'"$phase"'",
      "candidate_number": "'"$candidate_num"'",
      "usecase": {
        "name": "'"$USECASE_NAME"'",
        "sources": ["params", "phase_candidate_opts"]
      }
    }' \
    "http://${API_PROXY}/conduct/${NETWORK_NAME}/${original_benchmark_topology}/candidate_topology" \
    >"$original_candidate_list"
}

# input: original_candidate_list_x.json
function diff_benchmark_and_candidate_topologies() {
  original_benchmark_topology=$1
  phase=$2

  original_candidate_list=$(original_candidate_list_path "$phase")

  for original_candidate_topology in $(jq -r ".[] | .snapshot" "$original_candidate_list"); do
    diff_topologies "$original_benchmark_topology" "$original_candidate_topology"
  done
}

# Generate conduit topologies
generate_conduit_topology() {
  local network=$1
  local snapshot=$2           # e.g. "original_asis"
  local usecase=$3            # e.g. "refocus_topology"
  local blueprint_snapshot=$4 # e.g. "original_asis_blueprint"

  # echo "# Generate conduit topology: ${network}/${snapshot} (blueprint: ${blueprint_snapshot})"

  conduit_response=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -d "{\"usecase\": \"${usecase}\", \"blueprint_snapshot\": \"${blueprint_snapshot}\"}" \
    "http://${API_PROXY}/conduct/${network}/${snapshot}/conduit_topology")

  echo "$conduit_response"
}
