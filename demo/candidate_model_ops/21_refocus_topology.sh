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
splice_firewall_props

# add netoviz index
jq '{"index_data": [.[0]]}' network_index/${NETWORK_NAME}.json | \
curl -X POST -H "Content-Type: application/json" -d@- "http://${API_PROXY}/topologies/index"
