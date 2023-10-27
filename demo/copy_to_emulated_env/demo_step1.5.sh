#!/usr/bin/bash

# shellcheck disable=SC1091
source ./demo_vars

exec_parser="docker compose exec bgp-policy-parser"

# copy config files from configs dir to ttp dir for bgp-policy-parser
$exec_parser python collect_configs.py -n "$NETWORK_NAME"

# parse configuration files with TTP
$exec_parser python main.py -n "$NETWORK_NAME"

# post bgp policy data to model-conductor to merge it to topology data
$exec_parser python post_bgp_policies.py -n "$NETWORK_NAME"

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
