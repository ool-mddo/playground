#!/usr/bin/bash

# shellcheck disable=SC1091
source ./demo_vars
# shellcheck disable=SC1091
source ./scripts/up_emulated_env.sh

print_usage() {
  echo "Usage: $(basename "$0") -s <snapshot_name> [options]"
  echo "Options:"
  echo "  -s     Emulated snapshot name to boot (e.g. emulated_asis, emulated_asis_conduit1) [required]"
  echo "  -d     Debug/data check, without executing ansible-runner (clab)"
  echo "  -h     Display this help message"
}

# option check
# defaults
WITH_CLAB=true
snapshot_name=""
while getopts s:dh option; do
  case $option in
  s)
    snapshot_name="$OPTARG"
    ;;
  d)
    # data check, debug
    # -> skip state measurement/destroy of the emulated environment
    WITH_CLAB=false
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

if [ -z "$snapshot_name" ]; then
  echo "Error: -s <snapshot_name> is required" >&2
  print_usage
  exit 1
fi

echo # newline
echo "# check: snapshot_name = $snapshot_name"
echo "# check: with_clab = $WITH_CLAB"
echo # newline

# check that the target snapshot is registered in the netoviz index
netoviz_index=$(curl -s "http://${API_PROXY}/topologies/index")
if ! echo "$netoviz_index" | jq -e --arg snap "$snapshot_name" 'any(.[]; .snapshot == $snap)' >/dev/null; then
  echo "Error: snapshot '$snapshot_name' not found in netoviz index (run 21_generate_conduit.sh first)" >&2
  exit 1
fi

sudo cp /home/mddo/playground/topologies/mddo-fw/original_asis_conduit1/ns_convert_table.json /home/mddo/playground/topologies/mddo-fw/emulated_asis_conduit1
sudo cp /home/mddo/playground/topologies/mddo-fw/original_asis_conduit2/ns_convert_table.json /home/mddo/playground/topologies/mddo-fw/emulated_asis_conduit2
sudo cp /home/mddo/playground/topologies/mddo-fw/original_asis/ns_convert_table.json /home/mddo/playground/topologies/mddo-fw/emulated_asis

# read worker addresses as array
IFS=',' read -r -a remote_nodes <<< "$WORKER_ADDRESS"

# up_emulated_env takes the original (pre-conversion) snapshot name and derives the emulated one internally
original_snapshot_name=$(reverse_snapshot_name "$snapshot_name")
up_emulated_env "$original_snapshot_name" "${remote_nodes[0]}"
