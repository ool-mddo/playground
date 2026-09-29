#!/usr/bin/env python3
"""Convert a simplified topology-def.yaml into an RFC8345 blueprint topology.json.

Usage (run from usecases/refocus_topology):
    ./topology_def_to_blueprint.py [-n NETWORK] [-s SNAPSHOT] [-t TOPOLOGY_DEF_FILE]

Reads usecases/refocus_topology/<network>/<snapshot>/<topology_def_file>
and writes usecases/refocus_topology/<network>/<snapshot>/topology.json
"""

import argparse
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    print(
        "error: PyYAML is required to run this script (pip install pyyaml)",
        file=sys.stderr,
    )
    sys.exit(1)

LAYER3_NETWORK_ID = "layer3"
TP_KEY = "ietf-network-topology:termination-point"
LINK_KEY = "ietf-network-topology:link"
L3_NODE_ATTR = "mddo-topology:l3-node-attributes"
L3_TP_ATTR = "mddo-topology:l3-termination-point-attributes"


class TopologyDefError(Exception):
    """Raised when topology-def.yaml is malformed or inconsistent."""


def load_topology_def(path):
    if not path.is_file():
        raise TopologyDefError(f"topology-definition file not found: {path}")

    text = path.read_text()
    try:
        data = yaml.safe_load(text)
    except yaml.YAMLError as e:
        raise TopologyDefError(f"failed to parse {path} as YAML: {e}") from e

    if not isinstance(data, dict):
        raise TopologyDefError(f"{path}: top-level content must be a mapping")

    return data


def require_keys(mapping, keys, context):
    for key in keys:
        if key not in mapping:
            raise TopologyDefError(f"{context}: missing required key '{key}'")


def validate_and_normalize(data, source_path):
    zooms_raw = data.get("zooms")
    if not isinstance(zooms_raw, list) or not zooms_raw:
        raise TopologyDefError(f"{source_path}: 'zooms' must be a non-empty list")

    zooms = []
    seen_networks = set()
    for i, zoom_raw in enumerate(zooms_raw):
        zoom_ctx = f"{source_path}: zooms[{i}]"
        if not isinstance(zoom_raw, dict):
            raise TopologyDefError(f"{zoom_ctx}: must be a mapping")
        require_keys(zoom_raw, ["network", "supports", "nodes", "links"], zoom_ctx)

        network = zoom_raw["network"]
        if not isinstance(network, str) or not network:
            raise TopologyDefError(f"{zoom_ctx}: 'network' must be a non-empty string")
        if network in seen_networks:
            raise TopologyDefError(f"{zoom_ctx}: duplicate network name '{network}'")
        seen_networks.add(network)

        supports_target = zoom_raw["supports"]
        if not isinstance(supports_target, str) or not supports_target:
            raise TopologyDefError(
                f"{zoom_ctx} (network={network!r}): 'supports' must be a non-empty string"
            )

        if i == 0:
            if supports_target != LAYER3_NETWORK_ID:
                raise TopologyDefError(
                    f"{zoom_ctx} (network={network!r}): the first zoom must have "
                    f"supports: {LAYER3_NETWORK_ID!r} (got {supports_target!r})"
                )
            lower_node_names = None  # external network: no in-file validation
        else:
            prev = zooms[i - 1]
            if supports_target != prev["network"]:
                raise TopologyDefError(
                    f"{zoom_ctx} (network={network!r}): 'supports' must reference the "
                    f"immediately preceding zoom's network ({prev['network']!r}), "
                    f"got {supports_target!r}"
                )
            lower_node_names = set(prev["nodes"].keys())

        nodes = validate_nodes(zoom_raw["nodes"], lower_node_names, zoom_ctx, network)
        links = validate_links(zoom_raw["links"], nodes, zoom_ctx, network)

        zooms.append(
            {
                "network": network,
                "supports": supports_target,
                "nodes": nodes,
                "links": links,
            }
        )

    return zooms


def validate_nodes(nodes_raw, lower_node_names, zoom_ctx, network):
    if not isinstance(nodes_raw, dict) or not nodes_raw:
        raise TopologyDefError(f"{zoom_ctx} (network={network!r}): 'nodes' must be a non-empty mapping")

    nodes = {}
    for node_name, node_def in nodes_raw.items():
        node_ctx = f"{zoom_ctx} (network={network!r}) node {node_name!r}"
        if not isinstance(node_def, dict):
            raise TopologyDefError(f"{node_ctx}: node definition must be a mapping")
        require_keys(node_def, ["supports"], node_ctx)

        node_supports = node_def["supports"]
        if not isinstance(node_supports, list) or not node_supports:
            raise TopologyDefError(f"{node_ctx}: 'supports' must be a non-empty list")
        for s in node_supports:
            if not isinstance(s, str) or not s:
                raise TopologyDefError(f"{node_ctx}: 'supports' entries must be non-empty strings")
            if lower_node_names is not None and s not in lower_node_names:
                raise TopologyDefError(
                    f"{node_ctx}: supports references unknown node {s!r} "
                    f"(not found in the underlying zoom's nodes)"
                )

        extra_tps = node_def.get("tps", [])
        if not isinstance(extra_tps, list) or any(not isinstance(t, str) or not t for t in extra_tps):
            raise TopologyDefError(
                f"{node_ctx}: 'tps' (extra termination points without a link), if given, "
                f"must be a list of non-empty strings"
            )

        nodes[node_name] = {"supports": node_supports, "tps": list(extra_tps)}

    return nodes


def validate_links(links_raw, nodes, zoom_ctx, network):
    if not isinstance(links_raw, list) or not links_raw:
        raise TopologyDefError(f"{zoom_ctx} (network={network!r}): 'links' must be a non-empty list")

    links = []
    used_endpoints = set()
    for i, link_raw in enumerate(links_raw):
        link_ctx = f"{zoom_ctx} (network={network!r}) links[{i}]"
        if not isinstance(link_raw, dict):
            raise TopologyDefError(f"{link_ctx}: must be a mapping")
        require_keys(link_raw, ["endpoints"], link_ctx)

        endpoints = link_raw["endpoints"]
        if not isinstance(endpoints, list) or len(endpoints) != 2:
            raise TopologyDefError(f"{link_ctx}: 'endpoints' must be a list of exactly 2 items")

        parsed = []
        for ep in endpoints:
            if not isinstance(ep, str) or ep.count(":") != 1:
                raise TopologyDefError(
                    f"{link_ctx}: endpoint {ep!r} must be a string in 'node:tp' format"
                )
            node_name, tp_name = ep.split(":", 1)
            if not node_name or not tp_name:
                raise TopologyDefError(
                    f"{link_ctx}: endpoint {ep!r} must be a string in 'node:tp' format"
                )
            if node_name not in nodes:
                raise TopologyDefError(
                    f"{link_ctx}: endpoint {ep!r} references unknown node {node_name!r}"
                )
            key = (node_name, tp_name)
            if key in used_endpoints:
                raise TopologyDefError(
                    f"{link_ctx}: endpoint {ep!r} is used by more than one link in "
                    f"network {network!r}"
                )
            used_endpoints.add(key)
            parsed.append((node_name, tp_name))

        (src_node, src_tp), (dst_node, dst_tp) = parsed
        links.append((src_node, src_tp, dst_node, dst_tp))

        nodes[src_node]["tps"].append(src_tp)
        nodes[dst_node]["tps"].append(dst_tp)

    return links


def build_rfc8345(zooms):
    networks = []
    for i, zoom in enumerate(zooms):
        networks.append(build_network(zoom, is_base=(i == 0)))
    return {"ietf-network:networks": {"network": networks}}


def build_network(zoom, is_base):
    network_obj = {
        "network-id": zoom["network"],
        "network-types": {"mddo-topology:l3-network": {}},
        "node": build_nodes(zoom),
        LINK_KEY: build_links(zoom),
    }
    if not is_base:
        network_obj["supporting-network"] = [{"network-ref": zoom["supports"]}]
    return network_obj


def build_nodes(zoom):
    supports_target = zoom["supports"]
    nodes_out = []
    for node_name, node_data in zoom["nodes"].items():
        tps = []
        seen_tp = set()
        for tp in node_data["tps"]:
            if tp in seen_tp:
                continue
            seen_tp.add(tp)
            tps.append({"tp-id": tp, L3_TP_ATTR: {}})

        nodes_out.append(
            {
                "node-id": node_name,
                TP_KEY: tps,
                L3_NODE_ATTR: {"node-type": "node"},
                "supports": [
                    {"network-ref": supports_target, "node-ref": s}
                    for s in node_data["supports"]
                ],
            }
        )
    return nodes_out


def build_links(zoom):
    links_out = []
    for src_node, src_tp, dst_node, dst_tp in zoom["links"]:
        links_out.append(make_link(src_node, src_tp, dst_node, dst_tp))
        links_out.append(make_link(dst_node, dst_tp, src_node, src_tp))
    return links_out


def make_link(src_node, src_tp, dst_node, dst_tp):
    return {
        "link-id": f"{src_node},{src_tp},{dst_node},{dst_tp}",
        "source": {"source-node": src_node, "source-tp": src_tp},
        "destination": {"dest-node": dst_node, "dest-tp": dst_tp},
    }


def parse_args():
    parser = argparse.ArgumentParser(
        description="Convert topology-def.yaml into an RFC8345 blueprint topology.json"
    )
    parser.add_argument("-n", "--network", default="mddo-fw", help="network name (default: mddo-fw)")
    parser.add_argument(
        "-s", "--snapshot", default="original_asis_blueprint", help="snapshot name (default: original_asis_blueprint)"
    )
    parser.add_argument(
        "-t",
        "--topology-def",
        default="topology-def.yaml",
        help="topology-definition file name (default: topology-def.yaml)",
    )
    return parser.parse_args()


def main():
    args = parse_args()
    snapshot_dir = Path(args.network) / args.snapshot
    input_path = snapshot_dir / args.topology_def
    output_path = snapshot_dir / "topology.json"

    try:
        data = load_topology_def(input_path)
        zooms = validate_and_normalize(data, input_path)
    except TopologyDefError as e:
        print(f"error: {e}", file=sys.stderr)
        sys.exit(1)

    rfc8345 = build_rfc8345(zooms)

    import json

    output_path.write_text(json.dumps(rfc8345, indent=2) + "\n")
    print(f"wrote {output_path}")


if __name__ == "__main__":
    main()
