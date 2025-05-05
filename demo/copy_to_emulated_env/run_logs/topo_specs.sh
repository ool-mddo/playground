#!/usr/bin/bash
# usage: $0 <yyyymmddhhmm>
DATA_DIR="$1"

yaml2json() {
  python3 -c 'import sys,yaml,json; print(json.dumps(yaml.safe_load(sys.stdin.read())))'
}

echo "region, links, nodes(total), nodes(bridge), nodes(endpoint), nodes(router)"
tmpfile=".tmp"
for topo_yaml in $(find "$DATA_DIR" -name "*.yaml"); do
  region=$(echo "$topo_yaml" | sed -n 's|.*/\([0-9]\+\)region/.*|\1|p')
  link_len=$(cat "$topo_yaml" | yaml2json | jq '.topology.links | length')
  nodes_len=$(cat "$topo_yaml" | yaml2json | jq '.topology.nodes | length')
  nodes_br_len=$(cat "$topo_yaml" | yaml2json | jq '[.topology.nodes[] | select(.kind == "ovs-bridge")] | length')
  nodes_sv_len=$(cat "$topo_yaml" | yaml2json | jq '[.topology.nodes[] | select(.kind == "linux")] | length')
  nodes_rt_len=$(cat "$topo_yaml" | yaml2json | jq '[.topology.nodes[] | select(.kind == "juniper_crpd")] | length')
  echo "$region, $link_len, $nodes_len, $nodes_br_len, $nodes_sv_len, $nodes_rt_len" >> "$tmpfile"
done
sort -n "$tmpfile"
rm "$tmpfile"

