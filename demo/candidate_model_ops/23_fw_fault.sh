#!/usr/bin/bash

# shellcheck disable=SC1091
source ./demo_vars

print_usage() {
  echo "Usage: $(basename "$0") -s <snapshot_name> -n <fw_node> [options]"
  echo "Options:"
  echo "  -s     Emulated snapshot name (running clab environment, e.g. emulated_asis) [required]"
  echo "  -n     FW (vSRX) node name, e.g. site-a-fw-1 [required]"
  echo "  -m     Fault mode: link (default) / node / silent"
  echo "           link   : down/up the given interfaces at both ends (VM virtio NIC + peer node interface)"
  echo "           node   : stop/start the VM and down/up all its links (node failure)"
  echo "           silent : pause/resume the VM (links stay up, forwarding stops)"
  echo "  -i     JunOS interfaces of the node, comma separated (e.g. ge-0/0/1,ge-0/0/2) [required for link mode]"
  echo "  -u     Recover (up) instead of inject (down)"
  echo "  -h     Display this help message"
}

# option check
# defaults
snapshot_name=""
fw_node=""
mode="link"
state="down"
junos_interfaces=""
while getopts s:n:m:i:uh option; do
  case $option in
  s)
    snapshot_name="$OPTARG"
    ;;
  n)
    fw_node="$OPTARG"
    ;;
  m)
    mode="$OPTARG"
    ;;
  i)
    junos_interfaces="$OPTARG"
    ;;
  u)
    state="up"
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

if [ -z "$snapshot_name" ] || [ -z "$fw_node" ]; then
  echo "Error: -s <snapshot_name> and -n <fw_node> are required" >&2
  print_usage
  exit 1
fi
if [ "$mode" == "link" ] && [ -z "$junos_interfaces" ]; then
  echo "Error: -i <interfaces> is required for link mode" >&2
  print_usage
  exit 1
fi

# JunOS interface name -> Proxmox container eth name (l1_principal in ns_convert_table)
eth_interfaces=""
if [ "$mode" == "link" ]; then
  tp_table=$(curl -s "http://${API_PROXY}/topologies/${NETWORK_NAME}/${snapshot_name}/ns_convert_table" \
    | jq --arg node "$fw_node" '.tp_name_table[$node]')
  if [ -z "$tp_table" ] || [ "$tp_table" == "null" ]; then
    echo "Error: node '$fw_node' not found in ns_convert_table of ${NETWORK_NAME}/${snapshot_name}" >&2
    exit 1
  fi
  # FPC number of the node's own ports: its fabric member (eth3), e.g. ge-0/0/0 -> 0
  own_fpc=$(echo "$tp_table" | jq -r 'to_entries[] | select(.value.l1_principal == "eth3") | .key' \
    | sed -E 's|^[a-z]+-([0-9]+)/.*|\1|')

  IFS=',' read -r -a junos_if_list <<< "$junos_interfaces"
  eth_list=()
  for junos_if in "${junos_if_list[@]}"; do
    fpc=$(echo "$junos_if" | sed -E 's|^[a-z]+-([0-9]+)/.*|\1|')
    if [ "$fpc" != "$own_fpc" ]; then
      echo "Error: $junos_if is not a port of $fw_node (FPC $own_fpc), specify the HA partner node" >&2
      exit 1
    fi
    eth=$(echo "$tp_table" | jq -r --arg tp "$junos_if" '(.[$tp] // .[$tp + ".0"]).l1_principal // empty')
    if [ -z "$eth" ]; then
      echo "Error: interface $junos_if of $fw_node not found in ns_convert_table" >&2
      exit 1
    fi
    echo "# check: $fw_node $junos_if -> $eth"
    eth_list+=("$eth")
  done
  eth_interfaces=$(IFS=','; echo "${eth_list[*]}")
fi

echo # newline
echo "# fw_fault: snapshot=$snapshot_name, node=$fw_node, mode=$mode, state=$state, interfaces=$eth_interfaces"
echo # newline

# read worker addresses as array
IFS=',' read -r -a remote_nodes <<< "$WORKER_ADDRESS"

curl -s -X POST -H 'Content-Type: application/json' \
  -d '{
        "message": "fw_fault",
        "snapshot_name": "'"$snapshot_name"'",
        "node": "'"$fw_node"'",
        "mode": "'"$mode"'",
        "state": "'"$state"'",
        "interfaces": "'"$eth_interfaces"'"
      }' \
  "http://${remote_nodes[0]}:${WORKER_PORT}/endpoint"
