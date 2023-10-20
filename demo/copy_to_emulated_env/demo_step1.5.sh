#!/usr/bin/bash

# shellcheck disable=SC1091
source ./demo_vars

exec_parser="docker compose exec bgp-policy-parser"

# copy config files from configs dir to ttp dir for bgp-policy-parser
$exec_parser python collect_configs.py -n "$NETWORK_NAME"

# parse configuration files with TTP
$exec_parser python main.py

# post bgp policy data to model-conductor to merge it to topology data
$exec_parser python post_bgp_policies.py -n "$NETWORK_NAME"
