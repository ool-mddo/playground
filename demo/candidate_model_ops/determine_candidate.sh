#!/usr/bin/bash

function determine_candidate() {
  target_original_snapshot=$1
  target_emulated_snapshot="${target_original_snapshot/original/emulated}"

  echo "Target original snapshot: $target_original_snapshot"

  usecase_params="${USECASE_SESSION_DIR}/params.json"
  curl -s "http://$API_PROXY/usecases/${USECASE_NAME}/${NETWORK_NAME}/params" \
    > "$usecase_params"
  diff_with_asis_and_candidate="${USECASE_SESSION_DIR}/diff_${target_emulated_snapshot}.json"
  src_ss="emulated_asis"
  dst_ss="$target_emulated_snapshot"
  curl -s "http://${API_PROXY}/state-conductor/${USECASE_NAME}/${NETWORK_NAME}/snapshot_diff/${src_ss}/${dst_ss}" \
    > "$diff_with_asis_and_candidate"

  echo "Result state diff between ${src_ss} and ${dst_ss} (with names in original namespace)"
  python3 diff2csv.py -p "$usecase_params" -d "$diff_with_asis_and_candidate" | column -s, -t
}
