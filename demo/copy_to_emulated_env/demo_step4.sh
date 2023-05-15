### containerlab server login & sudo password Setting
###Example
###$ cat env/passwords 
###---
###"^SSH password:\\s*?$": "login password"
###"^BECOME password.*:\\s*?$": "login password"

source ./demo_vars

# generate original_tobe from emulated_tobe
curl -s -X POST -H 'Content-Type: application/json' \
  -d '{ "table_origin": "original_asis" }' \
  http://localhost:15000/conduct/mddo-ospf/ns_convert/emulated_tobe/original_tobe

# update netoviz index
curl -s -X POST -H 'Content-Type: application/json' \
  -d @<(jq '{ "index_data": . }' mddo_ospf_index.json ) \
  http://localhost:15000/topologies/index

# generate diff
curl -s -X POST -H 'Content-Type: application/json' \
  -d '{ "upper_layer3": true }' \
  http://localhost:15000/conduct/mddo-ospf/snapshot_diff/original_asis/original_tobe

# get diff
curl -s http://localhost:15000/conduct/mddo-ospf/model_merge/original_asis/original_tobe | jq .

