"""
python3 generate_iperf_command.py clab/flowdata.csv clab/static-route.yaml 
flowdata.csv
source,dest,rate
10.0.1.0/24,10.100.0.0/16,3355.99
10.0.2.0/24,10.100.0.0/16,1810.31
10.0.1.0/24,10.120.0.0/17,1397.12
10.0.3.0/24,10.100.0.0/16,809.95
10.0.2.0/24,10.110.0.0/21,468.14

static-route.yaml
---
- interfaces:
  - attribute:
      description: to_Seg-10.0.1.0-24_Ethernet2
      flag: []
      ip-address: [10.0.1.100/24]
    tp-id: eth1.0
  attribute:
    flag: []
    node-type: endpoint
    prefix: []
    static-route:
    - {description: default, interface: dynamic, metric: 10, next-hop: 10.0.1.1, preference: 1,
      prefix: 0.0.0.0/0}
  node: endpoint01-iperf1
"""

import argparse
import csv
import json
import yaml
from ipaddress import ip_network


# constant (alias)
TP_KEY = "interfaces"
L3TP_ATTR_KEY = "attribute"


def read_flow_data_file(file_path: str) -> list:
    with open(file_path, "r", newline="") as csv_file:
        reader = csv.DictReader(csv_file)
        return list(reader)


def read_static_route_data_file(file_path: str) -> list:
    with open(file_path) as file:
        return yaml.safe_load(file.read())


def ip_addr_from_l3tp_data(l3tp_data: dict) -> str:
    return str(l3tp_data[TP_KEY][0][L3TP_ATTR_KEY]["ip-address"][0].split("/")[0])


def l3tp_in_subnet(l3tp_data: dict, subnet_addr: str) -> bool:
    l3tp_ip_addr_str = ip_addr_from_l3tp_data(l3tp_data)
    l3tp_ip_addr = ip_network(f"{l3tp_ip_addr_str}/32")
    subnet_addr = ip_network(subnet_addr)
    return l3tp_ip_addr.subnet_of(subnet_addr)


def extract_l3tp_data(l3tp_data: dict) -> dict:
    return {"id": l3tp_data["node"], "ip_addr": ip_addr_from_l3tp_data(l3tp_data)}


def find_l3tp_by_flow(l3tp_data_list: list, subnet_addr: str) -> dict:
    l3tp_data = next(
        filter(lambda l3tp: l3tp_in_subnet(l3tp, subnet_addr), l3tp_data_list), None
    )
    # TODO: error check (if not found l3tp?)
    return extract_l3tp_data(l3tp_data)


def create_l3tp_dict(flow_data_list: list, l3tp_data_list: list) -> dict:
    """
    Assumption: There is one iperf endpoint for each source/destination subnet in the flow_data.
    """
    l3tp_dict = {}
    for flow_data in flow_data_list:
        if flow_data["source"] not in l3tp_data_list:
            l3tp_dict[flow_data["source"]] = find_l3tp_by_flow(
                l3tp_data_list, flow_data["source"]
            )
        if flow_data["dest"] not in l3tp_data_list:
            l3tp_dict[flow_data["dest"]] = find_l3tp_by_flow(
                l3tp_data_list, flow_data["dest"]
            )
    return l3tp_dict


def find_iperf_cmd_by_node_id(iperf_commands: list, dst_node_id: str) -> dict | None:
    return next(filter(lambda cmd: cmd["server_node"] == dst_node_id, iperf_commands), None)


def create_iperf_commands(flow_data_list: list, l3tp_dict: dict) -> list:
    iperf_commands = []
    for flow_data in flow_data_list:
        dst_node_id = l3tp_dict[flow_data["dest"]]["id"]
        target_iperf_command = find_iperf_cmd_by_node_id(iperf_commands, dst_node_id)
        source_info = {
            "client_node": l3tp_dict[flow_data["source"]]["id"],
            "server_address": l3tp_dict[flow_data["dest"]]["ip_addr"],
            "server_port": 0,  # define later
            "rate": float(flow_data["rate"]),
        }
        if target_iperf_command is None:
            iperf_commands.append({"server_node": dst_node_id, "clients": [source_info]})
        else:
            target_iperf_command["clients"].append(source_info)

    return iperf_commands


def assign_port_number(iperf_commands: list):
    iperf_commands.sort(key=lambda cmd: cmd["server_node"])
    for iperf_command in iperf_commands:
        iperf_command["clients"].sort(key=lambda cmd: cmd["client_node"])

        base_port_num = 5201
        for index, port in enumerate(iperf_command["clients"]):
            port["server_port"] = base_port_num + index


def main(flow_data_file: str, static_route_data_file: str):
    # read data
    flow_data_list = read_flow_data_file(flow_data_file)
    l3tp_data_list = read_static_route_data_file(static_route_data_file)

    # combine L3 TP information with flow_data
    l3tp_dict = create_l3tp_dict(flow_data_list, l3tp_data_list)
    iperf_commands = create_iperf_commands(flow_data_list, l3tp_dict)
    assign_port_number(iperf_commands)

    # output
    print(json.dumps(iperf_commands, indent=2))


if __name__ == "__main__":
    # argument check
    parser = argparse.ArgumentParser(description="generate iperf command")
    parser.add_argument(
        "-f", "--flow-data", type=str, required=True, help="flow data (csv)"
    )
    parser.add_argument(
        "-s",
        "--static-route-data",
        type=str,
        required=True,
        help="static-route data (json)",
    )
    args = parser.parse_args()

    main(args.flow_data, args.static_route_data)


"""
# client(src) iperf command:
root@endpoint01-iperf1:/# iperf3 -c 10.100.1.100 -b 100K -u -p 5201-52XX
# server(dst) iperf command:
root@endpoint02-iperf1:/# iperf3 -s -p 5201-52XX

output
---
- "server_node": "endpoint02-iperf1"
  "clients":
     - "server_port": 5201
       "client_node": "endpoint01-iperf1"
       "rate": "700.12"
       "server_address": "10.0.1.100"

"""
