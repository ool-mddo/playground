#!/usr/bin/bash

# shellcheck disable=SC1091
source ./demo_vars
# shellcheck disable=SC1091
source ./orig_ns_topology.sh

echo # newline

# Append snapshot entries (JSON array) to the current netoviz index
append_netoviz_entries() {
  local new_entries="$1"
  local current_index
  current_index=$(curl -s "http://${API_PROXY}/topologies/index")
  local updated_index
  updated_index=$(jq -n --argjson curr "${current_index}" --argjson new "${new_entries}" '$curr + $new')
  echo "{\"index_data\": ${updated_index}}" | \
    curl -s -X POST -H "Content-Type: application/json" -d@- "http://${API_PROXY}/topologies/index"
}

# clear all snapshots
curl -X DELETE "http://${API_PROXY}/topologies/${NETWORK_NAME}"

# Create original as-is topology data
generate_original_asis_topology

# BGP layer operation: Splice external-AS topology to original as-is topology
splice_external_as_topology
# Firewall property operation
splice_firewall_attributes

# add netoviz index (original_asis only, as the initial entry)
jq '{"index_data": [.[0]]}' "network_index/${NETWORK_NAME}.json" | \
  curl -X POST -H "Content-Type: application/json" -d@- "http://${API_PROXY}/topologies/index"

echo # newline

# Generate conduit topologies
conduit_response=$(generate_conduit_topology "${NETWORK_NAME}" "original_asis" "${USECASE_NAME}" "original_asis_blueprint")
echo "# Conduit response: ${conduit_response}"

# Append original_asis_conduit* entries to current netoviz index
original_conduit_entries=$(echo "${conduit_response}" | jq --arg nw "${NETWORK_NAME}" \
  '[.[] | {
    "label": (($nw | ascii_upcase) + " (" + .snapshot + ")"),
    "network": $nw,
    "snapshot": .snapshot,
    "file": "topology.json"
  }]')
append_netoviz_entries "${original_conduit_entries}"

echo # newline

# Convert namespace: original_asis -> emulated_asis, then add emulated_asis to netoviz index
convert_namespace "original_asis"
append_netoviz_entries "$(jq -n --arg nw "${NETWORK_NAME}" \
  '[{"label": (($nw | ascii_upcase) + " (emulated_asis)"), "network": $nw, "snapshot": "emulated_asis", "file": "topology.json"}]')"

# Convert namespace for each conduit snapshot and append each emulated entry to netoviz index
for conduit_snapshot in $(echo "${conduit_response}" | jq -r '.[] | .snapshot'); do
  convert_namespace "${conduit_snapshot}"
  emulated_snapshot=$(reverse_snapshot_name "${conduit_snapshot}")
  append_netoviz_entries "$(jq -n --arg nw "${NETWORK_NAME}" --arg snap "${emulated_snapshot}" \
    '[{"label": (($nw | ascii_upcase) + " (" + $snap + ")"), "network": $nw, "snapshot": $snap, "file": "topology.json"}]')"
done

