#!/usr/bin/bash

# shellcheck disable=SC1091
source ./util.sh

# output: original_asis topology (internal-AS only)
function generate_original_asis_topology() {
  network_name=$1

  curl -s -X DELETE "http://${API_PROXY}/conduct/${network_name}"
  curl -s -X POST -H 'Content-Type: application/json' \
    -d '{ "label": "original_asis", "phy_ss_only": true }' \
    "http://${API_PROXY}/conduct/${network_name}/original_asis/topology"
}

# output: original_asis topology (extended external-AS topology)
function splice_external_as_topology() {
  usecase_name=$1
  network_name=$2

  if ! use_bgp_proc "$network_name" original_asis ; then
    return 0
  fi

  echo # newline
  echo "Network:$network_name uses BGP, expand external-AS network and splice it into topology data"

  # bgp-policy data handling
  # parse configuration files with TTP
  curl -s -X POST -H "Content-Type: application/json" \
    -d '{}' \
    "http://${API_PROXY}/bgp_policy/${network_name}/original_asis/parsed_result"

  # post bgp policy data to model-conductor to merge it with topology data
  curl -s -X POST -H "Content-Type: application/json" \
    -d '{}' \
    "http://${API_PROXY}/bgp_policy/${network_name}/original_asis/topology"

  # generate external-AS topology
  external_as_json="${USECASE_SESSION_DIR}/external_as_topology.json"
  echo "$external_as_json"
  curl -s "http://${API_PROXY}/usecases/${usecase_name}/${network_name}/original_asis/external_as_topology?flow_data=event" \
    > "$external_as_json"

  # splice external-AS topology to original_asis (overwrite)
  curl -s -X POST -H "Content-Type: application/json" \
    -d @<(jq '{ "overwrite": true, "ext_topology_data": . }' "$external_as_json") \
    "http://${API_PROXY}/conduct/${network_name}/original_asis/splice_topology" \
    > /dev/null # ignore echo-back (topology json)
}

# output: original_candidate_xx topology
# output: original_candidate_list_x.json
function generate_original_candidate_topologies() {
  usecase_name=$1
  network_name=$2
  original_benchmark_topology=$3
  phase=$4
  candidate_num=$5

  original_candidate_list=$(original_candidate_list_path "$phase")

  curl -s -X POST -H 'Content-Type: application/json' \
    -d '{
      "phase_number": "'"$phase"'",
      "candidate_number": "'"$candidate_num"'",
      "usecase": {
        "name": "'"$usecase_name"'",
        "sources": ["params", "phase_candidate_opts"]
      }
    }' \
    "http://${API_PROXY}/conduct/${network_name}/${original_benchmark_topology}/candidate_topology" \
    > "$original_candidate_list"
}
