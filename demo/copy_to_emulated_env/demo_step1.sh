#!/usr/bin/bash

# shellcheck disable=SC1091
source ./demo_vars

# original as-is Create topology data
curl -s -X DELETE http://localhost:15000/conduct/${NETWORK_NAME}
curl -s -X POST -H 'Content-Type: application/json' \
  -d '{ "label": "OSPF model (original_asis)", "phy_ss_only": true }' \
  "http://${API_PROXY}/conduct/${NETWORK_NAME}/original_asis/topology"

# Add netoviz index
#curl -s -X POST -H 'Content-Type: application/json' \
#  -d @<(jq '{ "index_data": .[0:1] }' ${NETWORK_NAME}_index.json ) \
#  "http://${API_PROXY}/topologies/index"

curl -s -X POST -H 'Content-Type: application/json' \
  -d @<(jq '.[].network="${NETWORK_NAME}" | { "index_data": .[0:1] }' index.json ) \
  "http://${API_PROXY}/topologies/index"
