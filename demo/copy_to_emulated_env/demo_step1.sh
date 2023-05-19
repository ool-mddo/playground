### containerlab server login & sudo password Setting
###Example
###$ cat env/passwords 
###---
###"^SSH password:\\s*?$": "login password"
###"^BECOME password.*:\\s*?$": "login password"

source ./demo_vars

# original as-is Create topology data
curl -s -X DELETE http://localhost:15000/conduct/mddo-ospf
curl -s -X POST -H 'Content-Type: application/json' \
  -d '{ "label": "OSPF model (original_asis)", "phy_ss_only": true }' \
  http://localhost:15000/conduct/mddo-ospf/original_asis/topology

