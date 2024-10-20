#!/usr/bin/bash

print_usage() {
  echo "Usage: $(basename "$0") [options]"
  echo "Options:"
  echo "  -b     Benchmark topology name (default: original_asis)"
  echo "  -c     Number of candidate topology to generate (default: 2)"
  echo "  -d     Debug/data check, without executing ansible-runner (clab)"
  echo "  -p     Phase number (default: 1)"
  echo "  -h     Display this help message"
}

# option check
# defaults
WITH_CLAB=true
original_benchmark_topology=original_asis
candidate_num=2
phase=1
while getopts b:c:dp:h option; do
  case $option in
  b)
    original_benchmark_topology="$OPTARG"
    ;;
  c)
    candidate_num="$OPTARG"
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
echo "# check: candidate number = $candidate_num"
echo "# check: with_clab = $WITH_CLAB"
echo # newline

# pre-clean (phase/session data)
if [ "$phase" -eq 1 ]; then
  bash phase_pre_clean.sh
fi

# generate candidate topologies
bash 01_candidate_topology.sh -p "$phase" -c "$candidate_num" -b "$original_benchmark_topology"

# Boot emulated env of benchmark topology (usually phase 1 and for original_asis only)
if [ "$phase" -lt 2 ]; then
  if [ "$WITH_CLAB" == true ]; then
    bash 02_benchmark_env.sh -p "$phase" -b "$original_benchmark_topology"
  else
    bash 02_benchmark_env.sh -p "$phase" -b "$original_benchmark_topology" -d # debug
  fi
fi

# Boot each emulated env for candidate topology
if [ "$WITH_CLAB" == true ]; then
  bash 03_candidate_env.sh -p "$phase" -b "$original_benchmark_topology"
else
  bash 03_candidate_env.sh -p "$phase" -b "$original_benchmark_topology" -d # debug
fi
