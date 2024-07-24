#!/usr/bin/bash

# shellcheck disable=SC1091
source ./demo_vars

# original as-is Create topology data
curl -s -X DELETE "http://${API_PROXY}/conduct/${NETWORK_NAME}"
curl -s -X POST -H 'Content-Type: application/json' \
  -d '{ "label": "OSPF model (original_asis)", "phy_ss_only": true }' \
  "http://${API_PROXY}/conduct/${NETWORK_NAME}/original_asis/topology"

# Generate candidate configs
netoviz_candidates_list="${ARTIFACT_DIR}/netoviz_candidate_list.json"
curl -s -X POST -H 'Content-Type: application/json' \
  -d '{ "candidate_number": "'"$CANDIDATE_NUM"'", "usecase": "'"$USECASE_NAME"'"}' \
  "http://${API_PROXY}/conduct/${NETWORK_NAME}/original_asis/candidate_topology" \
  > "$netoviz_candidates_list"

# Add netoviz index
netoviz_original_asis_index="${ARTIFACT_DIR}/netoviz_original_asis_index.json"
jq '.[0:1]' "$NETWORK_INDEX" > "$netoviz_original_asis_index"
netoviz_candidates_index="${ARTIFACT_DIR}/netoviz_candidates_index.json"
jq 'map(. + {label: ( "\(.network | ascii_upcase) (\(.snapshot))"), file: "topology.json"})' "$netoviz_candidates_list" \
  > "$netoviz_candidates_index"
netoviz_index="${ARTIFACT_DIR}/netoviz_index.json"
jq -s '.[0] + .[1]' "$netoviz_original_asis_index" "$netoviz_candidates_index" > "$netoviz_index"

curl -s -X POST -H 'Content-Type: application/json' \
  -d @<(jq '{ "index_data": . }' "$netoviz_index") \
  "http://${API_PROXY}/topologies/index"
