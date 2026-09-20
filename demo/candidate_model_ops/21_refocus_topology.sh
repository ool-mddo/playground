#!/usr/bin/bash

# shellcheck disable=SC1091
source ./demo_vars
# shellcheck disable=SC1091
source ./orig_ns_topology.sh

echo # newline

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

# Append conduit snapshot entries to current netoviz index
current_index=$(curl -s "http://${API_PROXY}/topologies/index")
new_entries=$(echo "${conduit_response}" | jq --arg nw "${NETWORK_NAME}" \
  '[.[] | {
    "label": (($nw | ascii_upcase) + " (" + .snapshot + ")"),
    "network": $nw,
    "snapshot": .snapshot,
    "file": "topology.json"
  }]')
updated_index=$(jq -n --argjson curr "${current_index}" --argjson new "${new_entries}" '$curr + $new')
echo "{\"index_data\": ${updated_index}}" | \
  curl -s -X POST -H "Content-Type: application/json" -d@- "http://${API_PROXY}/topologies/index"

echo # newline

# Convert namespace: original_asis -> emulated_asis
convert_namespace "original_asis"

# Convert namespace for each conduit snapshot: original_asis_conduit<X> -> emulated_asis_conduit<X>
for conduit_snapshot in $(echo "${conduit_response}" | jq -r '.[] | .snapshot'); do
  convert_namespace "${conduit_snapshot}"
done

# Build emulated_asis* entries for netoviz index (emulated_asis + emulated_asis_conduit<X>)
emulated_entries=$(echo "${conduit_response}" | jq --arg nw "${NETWORK_NAME}" \
  '[{"label": (($nw | ascii_upcase) + " (emulated_asis)"), "network": $nw, "snapshot": "emulated_asis", "file": "topology.json"}] +
   [.[] | {
     "label": (($nw | ascii_upcase) + " (" + (.snapshot | gsub("^original"; "emulated")) + ")"),
     "network": $nw,
     "snapshot": (.snapshot | gsub("^original"; "emulated")),
     "file": "topology.json"
   }]')

# Append emulated_asis* entries to current netoviz index
current_index=$(curl -s "http://${API_PROXY}/topologies/index")
updated_index=$(jq -n --argjson curr "${current_index}" --argjson new "${emulated_entries}" '$curr + $new')
echo "{\"index_data\": ${updated_index}}" | \
  curl -s -X POST -H "Content-Type: application/json" -d@- "http://${API_PROXY}/topologies/index"

