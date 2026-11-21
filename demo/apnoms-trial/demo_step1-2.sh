#!/usr/bin/bash

# shellcheck disable=SC1091
source ./demo_vars

if use_bgp_proc "$NETWORK_NAME" original_asis ; then
  echo "Network:$NETWORK_NAME uses BGP, expand external-AS network and splice it into topology data"
else
  echo "Network:$NETWORK_NAME does not use BGP (Nothing to do in step1-2)"
  exit 0
fi

# bgp-policy data handling
# parse configuration files with TTP
curl -s -X POST -H "Content-Type: application/json" \
  -d '{}' \
  "http://${API_PROXY}/bgp_policy/${NETWORK_NAME}/original_asis/parsed_result"

# post bgp policy data to model-conductor to merge it with topology data
curl -s -X POST -H "Content-Type: application/json" \
  -d '{}' \
  "http://${API_PROXY}/bgp_policy/${NETWORK_NAME}/original_asis/topology"

