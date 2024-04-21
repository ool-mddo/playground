from jinja2 import Template
import subprocess
import json
import ipaddress
import csv
import random
import sys
import os

args = sys.argv
network_name = args[1]
usecase_name = args[2]
src_as = args[3]
dst_as = args[4]
subnet = args[5]
preferred_node = args[6]
redundant_node = args[7]

current_directory = os.path.dirname(os.path.abspath(__file__))
ext_as_topology_dir = os.path.join(current_directory, "external_as_topology")

externaldata = []
flowdata_file = os.path.join(current_directory, "flowdata.csv")
except_file = os.path.join(ext_as_topology_dir, "except.csv")
addl3_file = os.path.join(ext_as_topology_dir, "addl3.csv")

tempinstance = ""
srccommand = "curl http://localhost:15000/topologies/" + network_name + \
    "/original_asis/topology | jq -r '.[\"ietf-network:networks\"][\"network\"][] | select (.[\"network-id\"] == \"bgp_proc\")' | jq -r '.node[][\"ietf-network-topology:termination-point\"][] | select (.[\"mddo-topology:bgp-proc-termination-point-attributes\"][\"remote-as\"] == " + src_as + ")' | jq -s '.'"
dstcommand = "curl http://localhost:15000/topologies/" + network_name + \
    "/original_asis/topology | jq -r '.[\"ietf-network:networks\"][\"network\"][] | select (.[\"network-id\"] == \"bgp_proc\")' | jq -r '.node[][\"ietf-network-topology:termination-point\"][] | select (.[\"mddo-topology:bgp-proc-termination-point-attributes\"][\"remote-as\"] == " + dst_as + ")' | jq -s '.'"
localascommand = "curl http://localhost:15000/topologies/" + network_name + \
    "/original_asis/topology | jq -r '.[\"ietf-network:networks\"][\"network\"][] | select (.[\"network-id\"] == \"bgp_proc\")' | jq -r '.node[]' | jq -s '.'"
layer3command = "curl http://localhost:15000/topologies/" + network_name + \
    "/original_asis/topology | jq -r '.[\"ietf-network:networks\"][\"network\"][] | select (.[\"network-id\"] == \"layer3\")' | jq -r '.node[]' | jq -s '.'"
srctopology = subprocess.run(
    srccommand, shell=True, capture_output=True, text=True)
dsttopology = subprocess.run(
    dstcommand, shell=True, capture_output=True, text=True)
localastopology = subprocess.run(
    localascommand, shell=True, capture_output=True, text=True)
layer3topology = subprocess.run(
    layer3command, shell=True, capture_output=True, text=True)

subnet_list = list(ipaddress.ip_network(subnet).subnets(new_prefix=30))

with open(flowdata_file, "r") as f:
    csvreader = csv.DictReader(f)
    flowdata = list(csvreader)

with open(except_file, "r") as f:
    csvreader2 = csv.DictReader(f)
    exceptlist = list(csvreader2)

with open(addl3_file, "r") as f:
    csvreader3 = csv.DictReader(f)
    addl3list = list(csvreader3)


def subnetlist_init(subnet_list):
    subnet_data = []
    for subnet in subnet_list:
        subnet_data.append({"subnet": subnet, "ibgp_peer_desr": ""})
    return subnet_data


jinja_template_l3 = """
# frozen_string_literal: true
require 'netomox'

def register_layer3(nws)
  nws.register do
    network 'layer3' do
      type Netomox::NWTYPE_MDDO_L3
{%-  for node in topology %}
{%-  if "router" in node["instancetype"] %}
{%-     if "bdlink" in node["iflist"][0]|string()  %}
      bdlink %w[{{ node["iflist"][0]["attribute"]["bdlink"] }}]
{%-     endif %}
      node '{{node["instancename"]}}' do
        attribute( node_type: 'node' )
{%-    for item in node["iflist"] %}
        term_point '{{ item["ifname"] }}' do
{%-      if "netmask" in item|string() %}
          attribute( ip_addrs: %w[{{ item["address"] }}/{{item["netmask"]}}] )
{%-      else %}
          attribute( ip_addrs: %w[{{ item["address"] }}/30] )
{%-      endif %}
        end
{%-    endfor %}
      end
{%-  elif "segment" in node["instancetype"] %}
      node '{{ node["instancename"] }}' do
        attribute( node_type: 'segment', prefixes: [{ prefix: '{{ node["attribute"]["prefix"] }}', metric: 0 }] )
{%-    for item in node["iflist"] %}
        term_point '{{ item["ifname"] }}'
{%-    endfor %}
      end
{%-   for item in node["iflist"] %}
{%-     if "bdlink" in item|string()  %}
      bdlink %w[{{ item["attribute"]["bdlink"] }}]
{%-     endif %}
{%-   endfor %}
{%-  elif "endpoint" in node["instancetype"] %}
      node '{{node["instancename"]}}' do
        attribute(
          node_type: 'endpoint',
          static_routes: [{ prefix: '0.0.0.0/0', next_hop: '{{node["iflist"][0]["remoteaddress"]}}', description: 'default' }]
        )
        term_point '{{node["iflist"][0]["ifname"]}}' do
          attribute({ ip_addrs: %w[{{ node["iflist"][0]["address"] }}/{{ node["iflist"][0]["netmask"] }}] })
        end
      end
{%-   endif %}
{%- endfor %}
    end
  end
end
"""

jinja_template_bgp_proc = """
# frozen_string_literal: true
require 'netomox'

def register_bgp_proc(nws)
  nws.register do
    network 'bgp_proc' do
      type Netomox::NWTYPE_MDDO_BGP_PROC
      support 'layer3'

{%- for node in topology %}
{%-  if "router" in node["instancetype"] %}
      node '{{node["instancename"]}}' do
        support %w[layer3 {{node["instancename"]}}]
        attribute(
          flags: %w[ext-bgp-speaker],
          router_id: '0.0.0.{{ loop.index }}' # TODO
        )
{%-    for item in node["iflist"] %}
{%-      if "bgp" in item["protocol"]|string() %}
{%-      set localas = node["attribute"]["localas"] | string() %}
{%-      set remoteas = item["attribute"]["remoteas"] | string() %}
        term_point 'peer_{{ item["remoteaddress"] }}' do
          support %w[layer3 {{ node["instancename"] }}  {{ item["ifname"] }}]
          attribute(
{%-        if "true" in item["attribute"]["preferredFlag"]|string() %}
            flags: %w[ext-bgp-speaker-preferred],
{%-        endif %}
            local_as: {{ localas[:-3] }}_{{ localas[-3:] }},
            local_ip: '{{ item["address"] }}',
            remote_as: {{ remoteas[:-3] }}_{{ remoteas[-3:] }},
            remote_ip: '{{ item["remoteaddress"] }}'
          )
        end
{%-      endif %}
{%-    endfor %}
      end
{%-   for item in node["iflist"] %}
{%-     if "bdlink" in item|string() and item["attribute"]["bdlink"] != "already" and item["attribute"]["bdlink"] and  "peer" in  item["attribute"]["bdlink"] %}
      bdlink %w[{{ item["attribute"]["bdlink"] }}]
{%-     endif %}
{%-   endfor %}
{%-  endif %}
{%- endfor %}
    end
  end
end
"""

jinja_bgp_as = """
# frozen_string_literal: true
def register_bgp_as(nws)
  nws.register do
    network 'bgp_as' do
      type Netomox::NWTYPE_MDDO_BGP_AS
      support 'bgp_proc'

      # self
{%- set localas = localtopology[0]["ietf-network-topology:termination-point"][0]["mddo-topology:bgp-proc-termination-point-attributes"]["confederation"] | string() %}
      node 'as{{ localas }}' do
        attribute({ as_number: {{ localas[:-3] }}_{{ localas[-3:] }} })
        # supporting nodes and term-points will be generated from original-asis configs
{%- for node in localtopology %}
{%-   for tp in node["ietf-network-topology:termination-point"] %}
{%-     if  src_as|int == tp["mddo-topology:bgp-proc-termination-point-attributes"]["remote-as"]|int %}
{%-       if not tp["mddo-topology:bgp-proc-termination-point-attributes"]["remote-ip"]|string() in exceptlist|string() and not tp["mddo-topology:bgp-proc-termination-point-attributes"]["local-ip"]|string() in addl3list|string() %}
        term_point '{{ tp["tp-id"] }}' do
          attribute({ description: 'from TBD to TBD' })
          support %w[bgp_proc {{ node["mddo-topology:bgp-proc-node-attributes"]["router-id"] }} {{ tp["tp-id"] }} ]
        end
{%-       endif %}        
{%-     elif dst_as|int == tp["mddo-topology:bgp-proc-termination-point-attributes"]["remote-as"]|int %}
{%-       if not tp["mddo-topology:bgp-proc-termination-point-attributes"]["remote-ip"]|string() in exceptlist|string() and not tp["mddo-topology:bgp-proc-termination-point-attributes"]["local-ip"]|string() in addl3list|string() %}
        term_point '{{ tp["tp-id"] }}' do
          attribute({ description: 'from TBD to TBD' })
          support %w[bgp_proc {{ node["mddo-topology:bgp-proc-node-attributes"]["router-id"] }} {{ tp["tp-id"] }} ]
        end
{%-       endif %}        
{%-     endif %}
{%-   endfor %}
{%- endfor %}
      end
      node 'as{{ src_as }}' do
        attribute({ as_number: {{ src_as[:-3] }}_{{ src_as[-3:] }} })
{%- for node in externaldata %}
{%-   if "router" in node["instancetype"] and node["attribute"]["localas"]|int ==  src_as|int%}
{%-     for tp in node["iflist"] %} 
{%-       if   tp["attribute"]["remoteas"]|int == localas|int and not "direct" == tp["protocol"] %}        
        support %w[bgp_proc {{ node["instancename"] }}]
        term_point 'peer_{{ tp["remoteaddress"] }}' do
          attribute({ description: 'from TBD to TBD' })
          support %w[bgp_proc {{ node["instancename"] }} peer_{{ tp["remoteaddress"] }} ]
        end
{%-       endif %}
{%-     endfor %}
{%-   endif %}
{%- endfor %}
      end
      node 'as{{ dst_as }}' do
        attribute({ as_number: {{ dst_as[:-3] }}_{{ dst_as[-3:] }} })
{%- for node in externaldata %}        
{%-   if "router" in node["instancetype"] and node["attribute"]["localas"]|int ==  dst_as|int%}
{%-     for tp in node["iflist"] %}        
{%-       if tp["attribute"]["remoteas"]|int == localas|int  and not "direct" == tp["protocol"] %}        
        support %w[bgp_proc {{ node["instancename"] }}]
        term_point 'peer_{{ tp["remoteaddress"] }}' do
          attribute({ description: 'from TBD to TBD' })
          support %w[bgp_proc {{ node["instancename"] }} peer_{{ tp["remoteaddress"] }} ]
        end
{%-       endif %}
{%-     endfor %}
{%-   endif %}
{%- endfor %}
      end
      # inter AS links
{%- for node in externaldata %}
{%-   if "router" in node["instancetype"] and ( node["attribute"]["localas"]|int ==  src_as|int  or  node["attribute"]["localas"]|int ==  dst_as|int ) %}
{%-     for tp in node["iflist"] %}        
{%-       if  tp["attribute"]["remoteas"]|int == localas|int %}        
{%-         if not tp["address"] in addl3list|string() %}
      bdlink %w[as{{ localas }} peer_{{ tp["address"] }} as{{ node["attribute"]["localas"] }} peer_{{ tp["remoteaddress"] }}] 
{%-         endif %}
{%-       endif %}
{%-     endfor %}
{%-   endif %}
{%- endfor %}
    end
  end
end
"""


def find_exsited_external(externaldata, target_as, target_node1, target_node2):
    if len(externaldata) > 0:
        for nodeindex, node in enumerate(externaldata):
            if int(target_as) == node["attribute"]["localas"]:
                for iflist in node["iflist"]:
                    if str(target_node1) in iflist["attribute"]["remotenode"]:
                        return nodeindex
                    elif str(target_node2) in iflist["attribute"]["remotenode"]:
                        return nodeindex
    return None


def add_ebgp_node(externaldata, topologydata, layer3topology, addl3list, preferred_node, redundant_node):
    for index, router in enumerate(topologydata):
        baseifname = "Ethernet"
        for l3node in layer3topology:
            if str(l3node["node-id"]) == str(router["supporting-termination-point"][0]["node-ref"]):
                for l3if in l3node["ietf-network-topology:termination-point"]:
                    if router["supporting-termination-point"][0]["tp-ref"] in str(l3if["tp-id"]):
                        netmask = str(ipaddress.IPv4Interface(
                            l3if["mddo-topology:l3-termination-point-attributes"]["ip-address"][0]).network.prefixlen)
        instancename = "AS" + \
            str(router["mddo-topology:bgp-proc-termination-point-attributes"]
                ["remote-as"]) + "-" + str(index+1)
        if preferred_node and preferred_node in router["supporting-termination-point"][0]["node-ref"]:
            nodeindex = find_exsited_external(
                externaldata, router["mddo-topology:bgp-proc-termination-point-attributes"]["remote-as"], preferred_node, redundant_node)
            if nodeindex == None:
                ifname = baseifname + str("1")
                tempinstance = {
                    "instancename": instancename,
                    "instancetype": "router",
                    "attribute": {"localas": router["mddo-topology:bgp-proc-termination-point-attributes"]["remote-as"]},
                    "iflist": [
                        {
                            "ifname": ifname,
                            "protocol": "ebgp",
                            "address": router["mddo-topology:bgp-proc-termination-point-attributes"]["remote-ip"],
                            "remoteaddress": router["mddo-topology:bgp-proc-termination-point-attributes"]["local-ip"],
                            "netmask": netmask,
                            "attribute":
                            {
                                "remotenode": router["supporting-termination-point"][0]["node-ref"],
                                "remoteif": router["supporting-termination-point"][0]["tp-ref"],
                                "remoteas": router["mddo-topology:bgp-proc-termination-point-attributes"]["confederation"],
                                "preferredFlag": "true"
                            }
                        }
                    ]
                }
                externaldata.append(tempinstance)
            else:
                ifname = "Ethernet2"
                tmpiflist = {
                    "ifname": ifname,
                    "protocol": "ebgp",
                    "address": router["mddo-topology:bgp-proc-termination-point-attributes"]["remote-ip"],
                    "remoteaddress": router["mddo-topology:bgp-proc-termination-point-attributes"]["local-ip"],
                    "netmask": netmask,
                    "attribute":
                            {
                                "remotenode": router["supporting-termination-point"][0]["node-ref"],
                                "remoteif": router["supporting-termination-point"][0]["tp-ref"],
                                "remoteas": router["mddo-topology:bgp-proc-termination-point-attributes"]["confederation"],
                                "preferredFlag": "true"
                    }
                }
                externaldata[nodeindex]["iflist"].append(tmpiflist)

        elif redundant_node and redundant_node in router["supporting-termination-point"][0]["node-ref"]:
            nodeindex = find_exsited_external(
                externaldata, router["mddo-topology:bgp-proc-termination-point-attributes"]["remote-as"], preferred_node, redundant_node)
            if nodeindex == None:
                ifname = baseifname + str("1")
                tempinstance = {
                    "instancename": instancename,
                    "instancetype": "router",
                    "attribute": {"localas": router["mddo-topology:bgp-proc-termination-point-attributes"]["remote-as"]},
                    "iflist": [
                        {
                            "ifname": ifname,
                            "protocol": "ebgp",
                            "address": router["mddo-topology:bgp-proc-termination-point-attributes"]["remote-ip"],
                            "remoteaddress": router["mddo-topology:bgp-proc-termination-point-attributes"]["local-ip"],
                            "netmask": netmask,
                            "attribute":
                            {
                                "remotenode": router["supporting-termination-point"][0]["node-ref"],
                                "remoteif": router["supporting-termination-point"][0]["tp-ref"],
                                "remoteas": router["mddo-topology:bgp-proc-termination-point-attributes"]["confederation"],
                                "preferredFlag": "false"
                            }
                        }
                    ]
                }
                externaldata.append(tempinstance)
            else:
                ifname = "Ethernet2"
                tmpiflist = {
                    "ifname": ifname,
                    "protocol": "ebgp",
                    "address": router["mddo-topology:bgp-proc-termination-point-attributes"]["remote-ip"],
                    "remoteaddress": router["mddo-topology:bgp-proc-termination-point-attributes"]["local-ip"],
                    "netmask": netmask,
                    "attribute":
                            {
                                "remotenode": router["supporting-termination-point"][0]["node-ref"],
                                "remoteif": router["supporting-termination-point"][0]["tp-ref"],
                                "remoteas": router["mddo-topology:bgp-proc-termination-point-attributes"]["confederation"],
                                "preferredFlag": "false"
                    }
                }
                externaldata[nodeindex]["iflist"].append(tmpiflist)
        else:
            ifname = baseifname + str("1")
            tempinstance = {
                "instancename": instancename,
                "instancetype": "router",
                "attribute": {"localas": router["mddo-topology:bgp-proc-termination-point-attributes"]["remote-as"]},
                "iflist":
                [
                    {
                        "ifname": ifname,
                        "protocol": "ebgp",
                        "address": router["mddo-topology:bgp-proc-termination-point-attributes"]["remote-ip"],
                        "remoteaddress": router["mddo-topology:bgp-proc-termination-point-attributes"]["local-ip"],
                        "netmask": netmask,
                        "attribute":
                        {
                            "remotenode": router["supporting-termination-point"][0]["node-ref"],
                            "remoteif": router["supporting-termination-point"][0]["tp-ref"],
                            "remoteas": router["mddo-topology:bgp-proc-termination-point-attributes"]["confederation"],
                            "preferredFlag": "false"
                        }
                    }
                ]
            }
            exceptflag = 0
            for except_peer in exceptlist:
                if str(except_peer["except_peer"]) == str(router["mddo-topology:bgp-proc-termination-point-attributes"]["remote-ip"]) or str(except_peer["except_peer"]) == str(router["mddo-topology:bgp-proc-termination-point-attributes"]["local-ip"]):
                    print("skipped: " + except_peer["except_peer"])
                    exceptflag = 1

            if exceptflag == 0:
                externaldata.append(tempinstance)
    # addl3
    for addl3node in addl3list:
        instancename = "AS" + addl3node["peeras"] + "ADD"
        bdlink = instancename + " Ethernet1 " + \
            addl3node["srcrouter"] + " " + addl3node["srcif"]
        tempinstance = {
            "instancename": instancename,
            "instancetype": "router",
            "attribute": {"localas": addl3node["peeras"]},
            "iflist":
            [
                {
                    "ifname": "Ethernet1",
                    "protocol": "direct",
                    "address": addl3node["peeraddress"],
                    "remoteaddress":  addl3node["srcaddress"],
                    "netmask": addl3node["netmask"],
                    "attribute":
                    {
                        "bdlink": bdlink,
                        "remotenode": addl3node["srcrouter"],
                        "remoteif": addl3node["srcif"],
                        "remoteas": addl3node["srcas"]
                    }
                }
            ]
        }
        externaldata.append(tempinstance)
    return externaldata


def assignibgpsubnet(externaldata, ibgpsubnet, srcnode, dstnode, srcif, dstif):
    for subnet in ibgpsubnet:
        if str(srcnode) in str(subnet["ibgp_peer_desr"]) and str(dstnode) in str(subnet["ibgp_peer_desr"]):
            return "already assigned"
    for subnet in ibgpsubnet:
        if not subnet["ibgp_peer_desr"]:
            subnet["ibgp_peer_desr"] = srcnode + "_" + dstnode
            instancename = "Seg_" + str(subnet["subnet"])
            ifname01 = srcnode + "_" + srcif
            ifname02 = dstnode + "_" + dstif
            bdlink01 = srcnode + " " + srcif + " " + instancename + " " + ifname01
            bdlink02 = dstnode + " " + dstif + " " + instancename + " " + ifname02
            tempinstance = {
                "instancename": instancename,
                "instancetype": "segment",
                "attribute": {"prefix":  str(subnet["subnet"])},
                "iflist":
                [
                    {
                        "attribute": {
                            "bdlink":  bdlink01
                        },
                        "ifname": ifname01,
                        "protocol": "direct"
                    },
                    {
                        "attribute": {
                            "bdlink":  bdlink02
                        },
                        "ifname": ifname02,
                        "protocol": "direct"
                    }
                ]
            }

            externaldata.append(tempinstance)
            return subnet["subnet"]


def add_ibgp_node(externaldata):
    ibgpsubnet = subnetlist_init(subnet_list)
    for peer1node in externaldata:
        if str(peer1node["instancetype"]) == "router":
            for peer2node in externaldata:
                if str(peer2node["instancetype"]) == "router":
                    if int(peer1node["attribute"]["localas"]) == int(peer2node["attribute"]["localas"]) and str(peer1node["instancename"]) != str(peer2node["instancename"]):
                        getsubnet = assignibgpsubnet(externaldata, ibgpsubnet, peer1node["instancename"], peer2node["instancename"], "Ethernet" + str(
                            len(peer1node["iflist"])+1), "Ethernet" + str(len(peer2node["iflist"])+1))
                        if not "already" in str(getsubnet):

                            ifname = "Ethernet" + \
                                str(len(peer1node["iflist"])+1)
                            bdlink = str(peer1node["instancename"]) + " peer_" + str(getsubnet[2]) + " " + str(
                                peer2node["instancename"]) + " peer_" + str(getsubnet[1])
                            tempiflist = {
                                "ifname": ifname,
                                "protocol": "ibgp",
                                "address":  str(getsubnet[1]),
                                "remoteaddress":  str(getsubnet[2]),
                                "attribute": {"remoteas": peer1node["attribute"]["localas"], "bdlink": bdlink}
                            }
                            peer1node["iflist"].append(tempiflist)

                            ifname = "Ethernet" + \
                                str(len(peer2node["iflist"])+1)
                            tempiflist = {
                                "ifname": ifname,
                                "protocol": "ibgp",
                                "address":  str(getsubnet[2]),
                                "remoteaddress":  str(getsubnet[1]),
                                "attribute": {"remoteas": peer2node["attribute"]["localas"], "bdlink": "already"}
                            }
                            peer2node["iflist"].append(tempiflist)


def get_iperf_gateway(AS, externaldata):
    for node in externaldata:
        #print (str(node))
        #print (str(AS))
        if "router" in node["instancetype"] and ( "ADD" in node["instancename"] and str(AS) in node["instancename"]):
            interfacename = "Ethernet" + str(len(node["iflist"])+1)
            returndict = {
                "router": node["instancename"],
                "interface": interfacename
            }
            return returndict
    for node in externaldata:
        if "router" in node["instancetype"] and ( int(node["attribute"]["localas"]) == int(AS)):
            if random.choice([0, 1, 2, 3]) == 1:
                interfacename = "Ethernet" + str(len(node["iflist"])+1)
                returndict = {
                    "router": node["instancename"],
                    "interface": interfacename
                }
                return returndict
    return 0


def find_l3_node(AS, externaldata, preferred_node):
    for node in externaldata:
        if "router" in node["instancetype"] and int(node["attribute"]["localas"]) == int(AS):
            for iflist in node["iflist"]:
                if iflist["protocol"] == "ebgp" and iflist["attribute"]["preferredFlag"] == "true":
                    interfacename = "Ethernet" + str(len(node["iflist"])+1)
                    returndict = {
                        "router": node["instancename"],
                        "interface": interfacename
                    }
                    return returndict
    return 0


def assign_iperfSegment(flowdata, externaldata, src_as, dst_as, preferred_node):
    assigndata = []
    # src part
    srcprefixlist = []
    for flow in flowdata:
        srcprefixlist.append(flow["source"])
    uniq_srcprefixlist = list(set(srcprefixlist))

    for index, value in enumerate(uniq_srcprefixlist):
        gatewayinfo = find_l3_node(src_as, externaldata, preferred_node)
        if not gatewayinfo:
            gatewayinfo = get_iperf_gateway(src_as, externaldata)
        while gatewayinfo == 0:
            gatewayinfo = get_iperf_gateway(src_as, externaldata)
        for node in externaldata:
            if gatewayinfo["router"] in node["instancename"]:
                tempinterface = {
                    "ifname": gatewayinfo["interface"],
                    "address": str(ipaddress.IPv4Network(value)[1]),
                    "netmask": str(ipaddress.IPv4Network(value).prefixlen),
                    "protocol": "direct",
                    "remoteaddress": str(ipaddress.IPv4Network(value)[100]),
                    "attribute": {
                        "remotenode": "Seg_" + str(value)
                    }
                }
                node["iflist"].append(tempinterface)

        assigndata.append({
            "prefix": str(value),
            "iperfnode": "endpoint01-iperf" + str(index),
            "gateway": gatewayinfo
        })
        instancename = "Seg_" + str(value)
        ifname01 = gatewayinfo["router"] + "_" + gatewayinfo["interface"]
        ifname02 = "endpoint01-iperf" + str(index) + "_Ethernet1"
        bdlink01 = gatewayinfo["router"] + " " + \
            gatewayinfo["interface"] + " " + instancename + " " + ifname01
        bdlink02 = "endpoint01-iperf" + \
            str(index) + " Ethernet1" + " " + instancename + " " + ifname02
        tempinstance = {
            "instancename": instancename,
            "instancetype": "segment",
            "attribute": {
                "prefix":  str(value)
            },
            "iflist":
            [
                {
                    "attribute": {
                        "bdlink":  bdlink01
                    },
                    "ifname": ifname01,
                    "protocol": "direct"
                },
                {
                    "attribute": {
                        "bdlink":  bdlink02
                    },
                    "ifname": ifname02,
                    "protocol": "direct"
                }
            ]
        }

        externaldata.append(tempinstance)
        iperfinstancename = "endpoint01-iperf" + str(index)
        remotenode = "Seg_" + str(value)
        iperfinstance = {
            "instancename": iperfinstancename,
            "instancetype": "endpoint",
            "attribute": {},
            "iflist":
            [
                {
                    "attribute": {
                        "remotenode":  remotenode
                    },
                    "ifname": "Ethernet1",
                    "address": str(ipaddress.IPv4Network(value)[100]),
                    "remoteaddress": str(ipaddress.IPv4Network(value)[1]),
                    "netmask": str(ipaddress.IPv4Network(value).prefixlen),
                    "protocol": "direct"
                }
            ]
        }

        externaldata.append(iperfinstance)

    # dst part
    dstprefixlist = []
    for flow in flowdata:
        dstprefixlist.append(flow["dest"])
    uniq_dstprefixlist = list(set(dstprefixlist))

    for index, value in enumerate(uniq_dstprefixlist):
        gatewayinfo = get_iperf_gateway(dst_as, externaldata)
        while gatewayinfo == 0:
            gatewayinfo = get_iperf_gateway(dst_as, externaldata)
        for node in externaldata:
            if gatewayinfo["router"] in node["instancename"]:
                tempinterface = {
                    "ifname": gatewayinfo["interface"],
                    "address": str(ipaddress.IPv4Network(value)[1]),
                    "netmask": str(ipaddress.IPv4Network(value).prefixlen),
                    "protocol": "direct",
                    "remoteaddress": str(ipaddress.IPv4Network(value)[100]),
                    "attribute": {
                        "remotenode": "Seg_" + str(value)
                    }
                }
                node["iflist"].append(tempinterface)

        assigndata.append({
            "prefix": value,
            "iperfnode": "endpoint02-iperf" + str(index),
            "gateway": gatewayinfo
        })
        instancename = "Seg_" + str(value)
        ifname01 = gatewayinfo["router"] + "_" + gatewayinfo["interface"]
        ifname02 = "endpoint02-iperf" + str(index) + "_Ethernet1"
        bdlink01 = gatewayinfo["router"] + " " + \
            gatewayinfo["interface"] + " " + instancename + " " + ifname01
        bdlink02 = "endpoint02-iperf" + \
            str(index) + " Ethernet1" + " " + instancename + " " + ifname02
        tempinstance = {
            "instancename": instancename,
            "instancetype": "segment",
            "attribute": {
                "prefix":  str(value)
            },
            "iflist":
            [
                {
                    "attribute": {
                        "bdlink":  bdlink01
                    },
                    "ifname": ifname01,
                    "protocol": "direct"
                },
                {
                    "attribute": {
                        "bdlink":  bdlink02
                    },
                    "ifname": ifname02,
                    "protocol": "direct"
                }
            ]
        }

        externaldata.append(tempinstance)
        iperfinstancename = "endpoint02-iperf" + str(index)
        remotenode = "Seg_" + str(value)
        iperfinstance = {
            "instancename": iperfinstancename,
            "instancetype": "endpoint",
            "attribute": {},
            "iflist":
            [
                {
                    "attribute": {
                        "remotenode":  remotenode
                    },
                    "ifname": "Ethernet1",
                    "address": str(ipaddress.IPv4Network(value)[100]),
                    "remoteaddress": str(ipaddress.IPv4Network(value)[1]),
                    "netmask": str(ipaddress.IPv4Network(value).prefixlen),
                    "protocol": "direct"
                }
            ]
        }

        externaldata.append(iperfinstance)

    return assigndata


srctopologydata = json.loads(str(srctopology.stdout))
# print (str(srctopologydata))
dsttopologydata = json.loads(str(dsttopology.stdout))
l3topologydata = json.loads(str(layer3topology.stdout))
add_ebgp_node(externaldata, srctopologydata, l3topologydata,
              addl3list, preferred_node, redundant_node)
add_ebgp_node(externaldata, dsttopologydata, l3topologydata, [], "", "")
add_ibgp_node(externaldata)
localastopologydata = json.loads(str(localastopology.stdout))
template = Template(jinja_bgp_as)
result = template.render(localtopology=localastopologydata, src_as=src_as, dst_as=dst_as,
                         externaldata=externaldata, exceptlist=exceptlist, addl3list=addl3list)

# bgp_as
file = open(f"{ext_as_topology_dir}/bgp_as.rb", 'w')
file.write(result)
assign_iperfSegment(flowdata, externaldata, src_as, dst_as, preferred_node)
template = Template(jinja_template_l3)
result = template.render(topology=externaldata)
# layer3
file2 = open(f"{ext_as_topology_dir}/layer3.rb", 'w')
file2.write(result)
template = Template(jinja_template_bgp_proc)
result = template.render(topology=externaldata)
# bgp_proc
file3 = open(f"{ext_as_topology_dir}/bgp_proc.rb", 'w')
file3.write(result)
print(str(json.dumps(externaldata, indent=2)))