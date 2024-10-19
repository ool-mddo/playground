#!/usr/bin/bash

# shellcheck disable=SC1091
source ./demo_vars
# shellcheck disable=SC1091
source ./util.sh
# shellcheck disable=SC1091
source ./up_emulated_env.sh
# shellcheck disable=SC1091
source ./determine_candidate.sh

print_usage() {
  echo "Usage: $(basename "$0") [options]"
  echo "Options:"
  echo "  -d     Debug/data check, without executing ansible-runner (clab)"
  echo "  -p     Phase number (default: 1)"
  echo "  -h     Display this help message"
}

# option check
# defaults
WITH_CLAB=true
phase=1
while getopts dp:h option; do
  case $option in
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
echo "# check: with_clab = $WITH_CLAB"
echo # newline

# cache sudo credential
echo "Please enter your sudo password:"
sudo -v

# at first: prepare each emulated_candidate topology data
original_candidate_list=$(original_candidate_list_path "$phase")
for target_original_snapshot in $(jq -r ".[] | .snapshot" "$original_candidate_list")
do
  # convert namespace from original_candidate_i to emulated_candidate_i
  convert_namespace "$target_original_snapshot"
done

# update netoviz index
generate_netoviz_index "$phase" 3

# up each emulated env
for target_original_snapshot in $(jq -r ".[] | .snapshot" "$original_candidate_list")
do
  up_emulated_env "$target_original_snapshot"
  if [ "$WITH_CLAB" == true ]; then
    determine_candidate "$target_original_snapshot"
  else
    echo "# skip state diff, because WITH_CLAB=$WITH_CLAB"
  fi
done

# summary
if [ "$WITH_CLAB" == true ]; then
  echo # newline
  echo "Summary"
  for target_original_snapshot in $(jq -r ".[] | .snapshot" "$original_candidate_list")
  do
    determine_candidate "$target_original_snapshot" | grep -v "Target" | grep -v "Result"
  done
else
  echo "# skip state diff summary, because WITH_CLAB=$WITH_CLAB"
fi
