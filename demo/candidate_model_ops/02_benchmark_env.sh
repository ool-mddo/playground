#!/usr/bin/bash

# shellcheck disable=SC1091
source ./demo_vars
# shellcheck disable=SC1091
source ./util.sh
# shellcheck disable=SC1091
source ./up_emulated_env.sh

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

## cache sudo credential
#echo "Please enter your sudo password:"
#sudo -v

# at first: prepare emulated_asis topology data
# convert namespace from original namespace to emulated namespace
echo "$original_benchmark_topology"
convert_namespace "$original_benchmark_topology"

# Add netoviz index
generate_netoviz_index "$phase" 2

# up original_asis env
up_emulated_env "$original_benchmark_topology" "${remote_nodes[0]}"
