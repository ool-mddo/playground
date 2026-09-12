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

# Generate conduit topologies and update netoviz index
generate_conduit_topology() {
  local network=$1
  local snapshot=$2           # e.g. "original_asis"
  local usecase=$3            # e.g. "refocus_topology"
  local blueprint_snapshot=$4 # e.g. "original_asis_blueprint"

  echo "# Generate conduit topology: ${network}/${snapshot} (blueprint: ${blueprint_snapshot})"

  conduit_response=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -d "{\"usecase\": \"${usecase}\", \"blueprint_snapshot\": \"${blueprint_snapshot}\"}" \
    "http://${API_PROXY}/conduct/${network}/${snapshot}/conduit_topology")

  echo "# Conduit response: ${conduit_response}"

  # Append conduit snapshot entries to current netoviz index
  current_index=$(curl -s "http://${API_PROXY}/topologies/index")
  new_entries=$(echo "${conduit_response}" | jq --arg nw "${network}" \
    '[.[] | {
      "label": (($nw | ascii_upcase) + " (" + .snapshot + ")"),
      "network": $nw,
      "snapshot": .snapshot,
      "file": "topology.json"
    }]')
  updated_index=$(jq -n --argjson curr "${current_index}" --argjson new "${new_entries}" '$curr + $new')

  echo "{\"index_data\": ${updated_index}}" | \
    curl -s -X POST -H "Content-Type: application/json" -d@- "http://${API_PROXY}/topologies/index"
}

generate_conduit_topology "${NETWORK_NAME}" "original_asis" "${USECASE_NAME}" "original_asis_blueprint"
