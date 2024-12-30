#!/usr/bin/bash

# shellcheck disable=SC1091
source ./util.sh

function get_usecase_params() {
  curl -s "http://$API_PROXY/usecases/${USECASE_NAME}/${NETWORK_NAME}/params"
}

function get_state_diff() {
  src_ss=$1
  dst_ss=$2
  curl -s "http://${API_PROXY}/state-conductor/${USECASE_NAME}/${NETWORK_NAME}/snapshot_diff/${src_ss}/${dst_ss}"
}

function determine_candidate() {
  original_benchmark_topology=$1
  original_candidate_topology=$2
  emulated_benchmark_topology=$(reverse_snapshot_name "$original_benchmark_topology")
  emulated_candidate_topology=$(reverse_snapshot_name "$original_candidate_topology")

  echo "Target original topology: $original_candidate_topology"

  # save usecase params
  usecase_params="${USECASE_SESSION_DIR}/params.json"
  get_usecase_params >"$usecase_params"

  # save state diff
  diff_bench_candidate="${USECASE_SESSION_DIR}/diff_${emulated_candidate_topology}.json"
  get_state_diff "$emulated_benchmark_topology" "$emulated_candidate_topology" >"$diff_bench_candidate"

  echo "Result state diff between $emulated_benchmark_topology and $emulated_candidate_topology (with names in original namespace)"
  python3 diff2csv.py -p "$usecase_params" -d "$diff_bench_candidate" | column -s, -t
}
