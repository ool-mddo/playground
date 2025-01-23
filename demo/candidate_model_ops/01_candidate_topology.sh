#!/usr/bin/bash

# shellcheck disable=SC1091
source ./demo_vars
# shellcheck disable=SC1091
source ./orig_ns_topology.sh

print_usage() {
  echo "Usage: $(basename "$0") [options]"
  echo "Options:"
  echo "  -b     Benchmark topology name (default: original_asis)"
  echo "  -c     Number of candidate topology to generate (default: 2)"
  echo "  -p     Phase number (default: 1)"
  echo "  -h     Display this help message"
}

# option check
# defaults
original_benchmark_topology=original_asis
candidate_num=2
phase=1
while getopts b:c:p:h option; do
  case $option in
  b)
    original_benchmark_topology="$OPTARG"
    ;;
  c)
    candidate_num="$OPTARG"
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
echo "# check: candidate number = $candidate_num"
echo # newline

if [ "$phase" -eq 1 ] && [ "$original_benchmark_topology" == "original_asis" ]; then
  # Create original as-is topology data
  generate_original_asis_topology

  # Splice external-AS topology to original as-is topology
  splice_external_as_topology
fi

# convert benchmark topology name if specified emulated namespace topology
if [[ $phase -ge 2 && $original_benchmark_topology == emulated_* ]]; then
  original_benchmark_topology=$(reverse_snapshot_name "$original_benchmark_topology")
  echo "# check: (reverse) benchmark topology = $original_benchmark_topology"
fi

# Generate candidate topologies
generate_original_candidate_topologies "$original_benchmark_topology" "$phase" "$candidate_num"
# Take diff and overwrite
diff_benchmark_and_candidate_topologies "$original_benchmark_topology" "$phase"

# Add netoviz index
generate_netoviz_index "$phase" 1

echo # newline
