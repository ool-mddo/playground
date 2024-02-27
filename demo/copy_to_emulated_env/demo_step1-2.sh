#!/usr/bin/bash

# shellcheck disable=SC1091
source ./demo_vars

python3 ./generate.py ${NETWORK_NAME} ${SOURCE_AS} ${DEST_AS} "169.254.0.0/16" ${PREFERRED_NODE} ${REDUNDANT_NODE}
#python3 ./generate.py ${NETWORK_NAME} ${SOURCE_AS} ${DEST_AS} "100.0.0.0/8"

# bgp-policy data handling
# parse configuration files with TTP
curl -s -X POST -H "Content-Type: application/json" \
  -d '{}' \
  "http://${API_PROXY}/bgp_policy/${NETWORK_NAME}/original_asis/parsed_result"

# post bgp policy data to model-conductor to merge it with topology data
curl -s -X POST -H "Content-Type: application/json" \
  -d '{}' \
  "http://${API_PROXY}/bgp_policy/${NETWORK_NAME}/original_asis/topology"

# external-AS data handling
BIGLOBE_NETWORK_PATTERN="^biglobe.*$"
if [[ "$NETWORK_NAME" =~ $BIGLOBE_NETWORK_PATTERN ]]; then
  # generate external-AS topology
  external_as_json="${NETWORK_NAME}_ext.json"
  curl -s "http://${API_PROXY}/topologies/${NETWORK_NAME}/original_asis/external_as_topology" > "$external_as_json"
  # splice external-AS topology to original_asis (overwrite)
  curl -s -X POST -H "Content-Type: application/json" \
    -d @<(jq '{ "overwrite": true, "ext_topology_data": . }' "$external_as_json") \
    "http://${API_PROXY}/conduct/${NETWORK_NAME}/original_asis/splice_topology" \
    > /dev/null # ignore echo-back (topology json)
fi



