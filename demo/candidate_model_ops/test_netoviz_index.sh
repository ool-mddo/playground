#!/usr/bin/bash

# shellcheck disable=SC1091
source ./demo_vars

print_usage() {
  echo "Usage: $(basename "$0") [options]"
  echo "Options:"
  echo "  -p     Phase number (default: 1)"
  echo "  -s     Step number (default: 1)"
  echo "  -h     Display this help message"
}

# option check
# defaults
phase=1
step=1
while getopts p:s:h option; do
  case $option in
  p)
    phase="$OPTARG"
    ;;
  s)
    step="$OPTARG"
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

python3 netoviz_index.py -n "$NETWORK_NAME" -p "$phase" -s "$step" -i "$NETWORK_INDEX" -d "$USECASE_SESSION_DIR"
