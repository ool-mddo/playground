#!/usr/bin/bash

# shellcheck disable=SC1091
source ./demo_vars

# generate original_tobe from emulated_tobe
curl -s -X POST -H 'Content-Type: application/json' \
  -d '{ "table_origin": "original_asis" }' \
  "http://${API_PROXY}/conduct/${NETWORK_NAME}/ns_convert/emulated_tobe/original_tobe"

# update netoviz index
curl -s -X POST -H 'Content-Type: application/json' \
  -d @<(jq --arg network_name $NETWORK_NAME '.[].network=$network_name | { "index_data": . }' index.json) \
  "http://${API_PROXY}/topologies/index"


# generate diff
curl -s -X POST -H 'Content-Type: application/json' \
  -d '{ "upper_layer3": true }' \
  "http://${API_PROXY}/conduct/${NETWORK_NAME}/snapshot_diff/original_asis/original_tobe"

# get diff
curl -s "http://${API_PROXY}/conduct/${NETWORK_NAME}/model_merge/original_asis/original_tobe" | jq .
