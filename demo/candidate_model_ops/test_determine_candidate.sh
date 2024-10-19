#!/usr/bin/bash

# shellcheck disable=SC1091
source ./demo_vars
# shellcheck disable=SC1091
source ./util.sh
# shellcheck disable=SC1091
source ./determine_candidate.sh

print_usage() {
  echo "Usage: $(basename "$0") [options]"
  echo "Options:"
  echo "  -p     Phase number"
  echo "  -h     Display this help message"
}

# option check
# defaults
phase=1
while getopts dp:h option; do
  case $option in
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

original_candidate_list=$(original_candidate_list_path "$phase")

for target_original_snapshot in $(jq -r ".[] | .snapshot" "$original_candidate_list")
do
  determine_candidate "$target_original_snapshot" # | grep -v "Target" | grep -v "Result"
done
