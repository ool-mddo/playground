#!/usr/bin/bash

function determine_candidate() {
  target_original_snapshot=$1
  target_emulated_snapshot="${target_original_snapshot/original/emulated}"

  echo "Target original snapshot: $target_original_snapshot"

  diff_with_asis_and_candidate="${USECASE_SESSION_DIR}/diff_${target_emulated_snapshot}.json"
  src_ss="emulated_asis"
  dst_ss="$target_emulated_snapshot"
  params=$(curl -s "http://$API_PROXY/usecases/${USECASE_NAME}/${NETWORK_NAME}/params")
  node=$(echo "$params" | jq -r ".expected_traffic.original_targets[0].node")
  interface=$(echo "$params" | jq -r ".expected_traffic.original_targets[0].interface")
  curl -s "http://${API_PROXY}/state-conductor/${USECASE_NAME}/${NETWORK_NAME}/snapshot_diff/${src_ss}/${dst_ss}?interface=${interface}&node=${node}" \
    > "$diff_with_asis_and_candidate"

  echo "Result state diff between ${src_ss} and ${dst_ss} (with names in original namespace)"
  python3 diff2csv.py -j "$diff_with_asis_and_candidate" | column -s, -t
}

