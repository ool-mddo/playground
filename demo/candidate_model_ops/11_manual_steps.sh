#!/usr/bin/bash

# shellcheck disable=SC1091
source ./demo_vars
# shellcheck disable=SC1091
source ./orig_ns_topology.sh
# shellcheck disable=SC1091
source ./util.sh
# shellcheck disable=SC1091
source ./up_emulated_env.sh

echo # newline

# Create original as-is topology data
generate_original_asis_topology

# Splice external-AS topology to original as-is topology
splice_external_as_topology

# Copy original_asis to original_asis_preallocated
copy_original_asis_to_preallocated

# Splice preallocated ("empty") resource topology to original_asis pre-allocated topology
splice_preallocated_resources

# save diff between original_asis and original_asis_preallocated (to preallocated)
diff_topologies "original_asis" "original_asis_preallocated"

# convert namespace (make emulated env topology data)
convert_namespace "original_asis"
convert_namespace "original_asis_preallocated"
# NOTE:
#   The conversion of pre-allocated snapshots must be placed at the end.
#   This is because netomox-exp only retains the last conversion table.

# save diff between emulated_asis and emulated_asis_preallocated (to preallocated)
diff_topologies "emulated_asis" "emulated_asis_preallocated"

# add netoviz index
jq '[ .[]
      | select(.snapshot=="original_asis") as $a
      | [
          $a,
          ($a | .snapshot="original_asis_preallocated"
              | .label |= gsub("original_asis"; "original_asis_preallocated")),
          ($a | .snapshot |= gsub("original"; "emulated")
              | .label |= gsub("original"; "emulated")),
          ($a | .snapshot="original_asis_preallocated"
              | .label |= gsub("original_asis"; "original_asis_preallocated")
              | .snapshot |= gsub("original"; "emulated")
              | .label |= gsub("original"; "emulated"))
        ] | .[] ]' \
  "network_index/${NETWORK_NAME}.json" | \
  jq '{ "index_data": . }' | \
  curl -X POST -H "Content-Type: application/json" -d@- "http://${API_PROXY}/topologies/index"
