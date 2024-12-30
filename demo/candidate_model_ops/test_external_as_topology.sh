#!/usr/bin/bash

# shellcheck disable=SC1091
source ./demo_vars

INITIALIZE_TOPOLOGY=false
MAKE_EXT_AS_JSON=false
SPLICE_TOPOLOGY=false
while getopts eish option; do
  case $option in
  i)
    INITIALIZE_TOPOLOGY=true
    echo "# initialize topology" 1>&2
    ;;
  e)
    MAKE_EXT_AS_JSON=true
    echo "# make external-as json" 1>&2
    ;;
  s)
    SPLICE_TOPOLOGY=true
    echo "# splice topology" 1>&2
    ;;
  h)
    echo "# usage: specify -i to initialize topology"
    exit 0
    ;;
  *) ;;
  esac
done

if [ "$INITIALIZE_TOPOLOGY" = true ]; then
  curl -s -X DELETE "http://${API_PROXY}/conduct/${NETWORK_NAME}"
  curl -s -X POST -H 'Content-Type: application/json' \
    -d '{ "label": "original_asis", "phy_ss_only": true }' \
    "http://${API_PROXY}/conduct/${NETWORK_NAME}/original_asis/topology"

  # parse configuration files with TTP
  curl -s -X POST -H "Content-Type: application/json" \
    -d '{}' \
    "http://${API_PROXY}/bgp_policy/${NETWORK_NAME}/original_asis/parsed_result"

  # post bgp policy data to model-conductor to merge it with topology data
  curl -s -X POST -H "Content-Type: application/json" \
    -d '{}' \
    "http://${API_PROXY}/bgp_policy/${NETWORK_NAME}/original_asis/topology"
fi

if [ "$MAKE_EXT_AS_JSON" = true ]; then
  # generate external-AS topology
  external_as_json="${USECASE_SESSION_DIR}/external_as_topology.json"
  curl -s "http://${API_PROXY}/usecases/${USECASE_NAME}/${NETWORK_NAME}/original_asis/external_as_topology?flow_data=event" \
    >"$external_as_json"
fi

if [ "$SPLICE_TOPOLOGY" = true ]; then
  # splice external-AS topology to original_asis (overwrite)
  curl -s -X POST -H "Content-Type: application/json" \
    -d @<(jq '{ "overwrite": true, "ext_topology_data": . }' "$external_as_json") \
    "http://${API_PROXY}/conduct/${NETWORK_NAME}/original_asis/splice_topology"
fi
