#!/usr/bin/bash

# shellcheck disable=SC1091
source ./demo_vars

# Create original as-is topology data
curl -s -X DELETE "http://${API_PROXY}/conduct/${NETWORK_NAME}"
curl -s -X POST -H 'Content-Type: application/json' \
  -d '{ "label": "original_asis", "phy_ss_only": true }' \
  "http://${API_PROXY}/conduct/${NETWORK_NAME}/original_asis/topology"

if use_bgp_proc "$NETWORK_NAME" original_asis ; then
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
  curl -s "http://${API_PROXY}/usecases/${USECASE_NAME}/external_as_topology?network=${NETWORK_NAME}" \
    > "$external_as_json"

  # splice external-AS topology to original_asis (overwrite)
  curl -s -X POST -H "Content-Type: application/json" \
    -d @<(jq '{ "overwrite": true, "ext_topology_data": . }' "$external_as_json") \
    "http://${API_PROXY}/conduct/${NETWORK_NAME}/original_asis/splice_topology" \
    > /dev/null # ignore echo-back (topology json)
fi

# Generate candidate topologies
original_candidate_list="${USECASE_SESSION_DIR}/original_candidate_list.json"
curl -s -X POST -H 'Content-Type: application/json' \
  -d '{
    "candidate_number": "'"$CANDIDATE_NUM"'",
    "usecase": {
      "name": "'"$USECASE_NAME"'",
      "sources": ["params", "flow_data"]
    }
  }' \
  "http://${API_PROXY}/conduct/${NETWORK_NAME}/original_asis/candidate_topology" \
  > "$original_candidate_list"

# Add netoviz index
netoviz_asis_index="${USECASE_SESSION_DIR}/netoviz_asis_index.json"
jq '.[0:1]' "$NETWORK_INDEX" > "$netoviz_asis_index"
netoviz_original_candidates_index="${USECASE_SESSION_DIR}/netoviz_original_candidates_index.json"
filter='map(. + {label: ( "\(.network | ascii_upcase) (\(.snapshot))"), file: "topology.json"})'
jq "$filter" "$original_candidate_list" > "$netoviz_original_candidates_index"
netoviz_index="${USECASE_SESSION_DIR}/netoviz_index.json"
jq -s '.[0] + .[1]' "$netoviz_asis_index" "$netoviz_original_candidates_index" > "$netoviz_index"

curl -s -X POST -H 'Content-Type: application/json' \
  -d @<(jq '{ "index_data": . }' "$netoviz_index") \
  "http://${API_PROXY}/topologies/index"
bash generate_scrape.sh
echo # newline
