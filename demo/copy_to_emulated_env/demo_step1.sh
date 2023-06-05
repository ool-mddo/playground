#!/usr/bin/bash

# shellcheck disable=SC1091
source ./demo_vars

# original as-is Create topology data
curl -s -X DELETE http://localhost:15000/conduct/mddo-ospf
curl -s -X POST -H 'Content-Type: application/json' \
  -d '{ "label": "OSPF model (original_asis)", "phy_ss_only": true }' \
  "http://${API_PROXY}/conduct/mddo-ospf/original_asis/topology"

# Add netoviz index
curl -s -X POST -H 'Content-Type: application/json' \
  -d @<(jq '{ "index_data": .[0:1] }' mddo_ospf_index.json ) \
  "http://${API_PROXY}/topologies/index"
