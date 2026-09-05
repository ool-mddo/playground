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
