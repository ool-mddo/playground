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
- ietf-network-topology:termination-point:
  - mddo-topology:l3-termination-point-attributes:
      description: to_Seg-10.0.1.0-24_Ethernet2
      flag: []
      ip-address: [10.0.1.100/24]
    tp-id: eth1.0
  mddo-topology:l3-node-attributes:
    flag: []
    node-type: endpoint
    prefix: []
    static-route:
    - {description: default, interface: dynamic, metric: 10, next-hop: 10.0.1.1, preference: 1,
      prefix: 0.0.0.0/0}
  node-id: endpoint01-iperf1

"""
import ipaddress, yaml, json, csv, sys
from ipaddress import ip_network

csvdata = []

with open(sys.argv[1], "r", newline='') as csv_file:
    reader = csv.DictReader(csv_file)
    for row in reader:
      csvdata.append(row)
    csv_file.close()

with open(sys.argv[2]) as file:
    config = yaml.safe_load(file.read())

start_port = 5201
iperf_cmd = []
for iperf in config:
    target_ip = str(iperf["ietf-network-topology:termination-point"][0]["mddo-topology:l3-termination-point-attributes"]["ip-address"][0].split('/')[0])
    for flowdata in csvdata:
        ip1 = ip_network(flowdata["dest"])
        ip2 = ip_network(str( target_ip + "/32"))
        if ip2.subnet_of(ip1):
            source_network=ip_network(flowdata["source"])
            for iperf_client in config:
                source_ip=str(iperf_client["ietf-network-topology:termination-point"][0]["mddo-topology:l3-termination-point-attributes"]["ip-address"][0].split('/')[0])
                source_ip_address=ip_network(str(source_ip + "/32"))
                if source_ip_address.subnet_of(source_network):
                    if not  str(iperf["node-id"]) in str(iperf_cmd):
                        iperf_cmd.append({"node": str(iperf["node-id"]), "port": [] })
  
                    for index, dest_node in enumerate(iperf_cmd):
                        if  str(iperf["node-id"]) in dest_node["node"]:
                            tmpport = {"source": iperf_client["node-id"], "dest_address": target_ip, "number": int(start_port + len(iperf_cmd[index]["port"])), "rate" : str(flowdata["rate"] )}
                            iperf_cmd[index]["port"].append(tmpport)
print(json.dumps(iperf_cmd, indent=2))
"""
source iperf command:
root@endpoint01-iperf1:/# iperf3 -c 10.100.0.100 -b 100K -u -p 5201-52XX
dest iperf command:
root@endpoint02-iperf1:/# iperf3 -s -p 5201-52XX

output 
- "node": "endpoint01-iperf1"
  "port":
     - "number": 5201
       "source": "endpoint02-iperf1"
       "bandwidth": "700.12"
       "dest_address": "10.0.1.100"
"""
