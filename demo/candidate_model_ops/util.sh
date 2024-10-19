#!/usr/bin/bash

# step1-2, 2-2: check if the network has bgp(_proc) layer
function use_bgp_proc() {
  network_name=$1
  snapshot_name=$2

  curl -s "http://${API_PROXY}/topologies/${network_name}/${snapshot_name}/topology" \
    | jq '."ietf-network:networks".network[] | ."network-types" | keys[0]' \
    | grep -q mddo-topology:bgp-proc-network
  return $?
}

function original_candidate_list_path() {
  phase=$1

  echo "${USECASE_SESSION_DIR}/original_candidate_list_${phase}.json"
}

function reverse_snapshot_name() {
  snapshot_name=$1
  if [[ $snapshot_name == original_* ]]; then
    echo "${snapshot_name/original/emulated}"
  elif [[ $snapshot_name == emulated_* ]]; then
    echo "${snapshot_name/emulated/original}"
  else
    echo "__unknown_namespace__"
  fi
}

function convert_namespace() {
  src_ss=$1
  dst_ss=$(reverse_snapshot_name "$src_ss")

  echo "Convert namespace from:$src_ss to:$dst_ss"

  curl -s -X POST -H 'Content-Type: application/json' \
    -d '{ "table_origin": "'"$src_ss"'" }' \
    "http://${API_PROXY}/conduct/${NETWORK_NAME}/ns_convert/${src_ss}/${dst_ss}"

  echo # newline
}

function post_netoviz_index() {
  netoviz_index=$1

  curl -s -X POST -H 'Content-Type: application/json' \
    -d @<(jq '{ "index_data": . }' "$netoviz_index") \
    "http://${API_PROXY}/topologies/index"
}

function generate_netoviz_index() {
  phase=$1
  step=$2

  netoviz_index="${USECASE_SESSION_DIR}/netoviz_index.json"
  python3 netoviz_index.py -n "$NETWORK_NAME" -p "$phase" -s "$step" -i "$NETWORK_INDEX" -d "$USECASE_SESSION_DIR" \
    > "$netoviz_index"
  post_netoviz_index "$netoviz_index"
}
