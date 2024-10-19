import json
import argparse
import os
import re
import sys


def open_json(json_file):
    with open(json_file, 'r') as f:
        return json.load(f)


def netoviz_index_item(network, snapshot):
    return {
        "label": f"{network.upper()} ({snapshot})",
        "network": network,
        "snapshot": snapshot,
        "file": "topology.json"
    }


def find_benchmark_index(network_index_data, network, benchmark_topology):
    return next((n for n in network_index_data if n["network"] == network and n["snapshot"] == benchmark_topology), None)


def candidates_index_items(original_candidate_data):
    return [netoviz_index_item(c["network"], c["snapshot"]) for c in original_candidate_data]


def rev_candidates_index_items(original_candidate_data):
    return [netoviz_index_item(c["network"], reverse_ns_topology_name(c["snapshot"])) for c in original_candidate_data]


def reverse_ns_topology_name(topology_name):
    if re.match(r"original_.*", topology_name):
        return topology_name.replace('original', 'emulated')
    if re.match(r"emulated_.*", topology_name):
        return topology_name.replace('emulated', 'original')

    # error (not converted)
    return "__unknown_namespace_keyword__"


def find_benchmark_topology(original_candidate_data):
    # NOTE: all items in original_candidate_list have same (original) benchmark-snapshot for each phase.
    #   (in a phase, all candidate data are generated from one benchmark-snapshot.)
    if len(original_candidate_data) > 0:
        return original_candidate_data[0]["benchmark_snapshot"]
    else:
        return "__benchmark_snapshot_not_found__"


def step_count(phase, step):
    # step in range(1, 3)
    return phase * 10 + step


def append_netoviz_index_item(netoviz_index, index_item):
    item = next((i for i in netoviz_index if i["network"] == index_item["network"] and i["snapshot"] == index_item["snapshot"]), None)
    if item:
        return # already exists same item

    netoviz_index.append(index_item)


def append_netoviz_index(netoviz_index, network_index_data, network, benchmark_topology):
    benchmark_index_data = find_benchmark_index(network_index_data, network, benchmark_topology)
    if benchmark_index_data:
        append_netoviz_index_item(netoviz_index, benchmark_index_data)
    else:
        append_netoviz_index_item(netoviz_index, netoviz_index_item(network, benchmark_topology))


def main():
    parser = argparse.ArgumentParser(description="Generate netoviz index (json)")
    parser.add_argument('-n', '--network', type=str, required=True, help="Network name")
    parser.add_argument('-p', '--phase', type=int, required=True, help='Phase number')
    parser.add_argument('-s', '--step', type=int, required=True, help='Step number in a phase')
    parser.add_argument('-i', '--network_index', type=str, default=os.environ.get('NETWORK_INDEX'), help="Network index file (json)")
    parser.add_argument('-d', '--session_dir', type=str, default=os.environ.get('USECASE_SESSION_DIR'), help='Usecase session dir')
    args = parser.parse_args()

    if args.network_index is None or args.session_dir is None:
        print(f"network_index(={args.network_index}) and/or session_dir(={args.session_dir}) are not specified", file=sys.stderr)
        parser.print_help()
        sys.exit(1)

    network_index_data = open_json(args.network_index)

    netoviz_index = []
    step_count_end = step_count(args.phase, args.step)

    for phase in range(1, args.phase + 1):
        original_candidate_data = open_json(f"{args.session_dir}/original_candidate_list_{phase}.json")
        benchmark_topology = find_benchmark_topology(original_candidate_data)

        if step_count(phase, 1) <= step_count_end:
            # add index of original benchmark topology
            append_netoviz_index(netoviz_index, network_index_data, args.network, benchmark_topology)

            # add index of original candidate topologies
            netoviz_index.extend(candidates_index_items(original_candidate_data))

        if step_count(phase, 2) <= step_count_end:
            # add index of emulated benchmark topology
            rev_benchmark_topology = reverse_ns_topology_name(benchmark_topology)
            append_netoviz_index(netoviz_index, network_index_data, args.network, rev_benchmark_topology)

        if step_count(phase, 3) <= step_count_end:
            # add index of emulated candidate topologies
            netoviz_index.extend(rev_candidates_index_items(original_candidate_data))

    print(json.dumps(netoviz_index))

if __name__ == '__main__':
    main()
