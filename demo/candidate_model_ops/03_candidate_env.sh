#!/usr/bin/bash

# shellcheck disable=SC1091
source ./demo_vars
# shellcheck disable=SC1091
source ./util.sh
# shellcheck disable=SC1091
source ./up_emulated_env.sh
# shellcheck disable=SC1091
source ./determine_candidate.sh
# read worker addresses as array
IFS=',' read -r -a remote_nodes <<< "$WORKER_ADDRESS"

print_usage() {
  echo "Usage: $(basename "$0") [options]"
  echo "Options:"
  echo "  -b     Benchmark topology name (default: original_asis)"
  echo "  -d     Debug/data check, without executing ansible-runner (clab)"
  echo "  -p     Phase number (default: 1)"
  echo "  -h     Display this help message"
}

# option check
# defaults
WITH_CLAB=true
original_benchmark_topology=original_asis
phase=1
while getopts b:dp:h option; do
  case $option in
  b)
    original_benchmark_topology="$OPTARG"
    ;;
  d)
    # data check, debug
    # -> without container lab; does not build emulated-env
    WITH_CLAB=false
    ;;
  p)
    phase="$OPTARG"
    ;;
  h)
    print_usage
    exit 0
    ;;
  *)
    echo "Unknown option detected, -$OPTARG" >&2
    print_usage
    exit 1
    ;;
  esac
done

echo # newline
echo "# check: phase = $phase"
echo "# check: benchmark topology = $original_benchmark_topology"
echo "# check: with_clab = $WITH_CLAB"
echo # newline

# cache sudo credential
echo "Please enter your sudo password:"
sudo -v

# at first: prepare each emulated_candidate topology data
original_candidate_list=$(original_candidate_list_path "$phase")
for original_candidate_topology in $(jq -r ".[] | .snapshot" "$original_candidate_list")
do
  # convert namespace from original_candidate_i to emulated_candidate_i
  convert_namespace "$original_candidate_topology"
  # take diff and overwrite
  diff_emulated_topologies "$original_benchmark_topology" "$original_candidate_topology"
done

# update netoviz index
generate_netoviz_index "$phase" 3

# up each emulated env
loop_index=1
remote_nodes_num=${#remote_nodes[@]}
echo "Number of remote_nodes: $remote_nodes_num"
for original_candidate_topology in $(jq -r ".[] | .snapshot" "$original_candidate_list")
do
  # select remote node (worker) by round-robin (if remote_nodes_num=1 then always 0)
  node_index=$((loop_index % remote_nodes_num))
  echo "execute up emulated, loop=$loop_index, remote=${remote_nodes[$node_index]} (node_index:$node_index)"
  up_emulated_env "$original_candidate_topology" "${remote_nodes[$node_index]}"
  ((loop_index++))

  if [ "$WITH_CLAB" == true ]; then
    determine_candidate "$original_benchmark_topology" "$original_candidate_topology"
  else
    echo "# skip state diff, because WITH_CLAB=$WITH_CLAB"
  fi
done

# summary
if [ "$WITH_CLAB" == true ]; then
  echo # newline
  echo "Summary"
  for original_candidate_topology in $(jq -r ".[] | .snapshot" "$original_candidate_list")
  do
    determine_candidate "$original_benchmark_topology" "$original_candidate_topology" |
      grep -v "Target" | grep -v "Result"
  done
else
  echo "# skip state diff summary, because WITH_CLAB=$WITH_CLAB"
fi
mv ../../assets/prometheus/orig.prometheus.yaml ../../assets/prometheus/prometheus.yaml
