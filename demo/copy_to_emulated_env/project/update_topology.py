import json,sys
convert_path=sys.argv[1]
topology_path=sys.argv[2]

with open( convert_path , 'r') as convert_open:
  source_convert_table = json.load(convert_open)

with open( topology_path , 'r') as topology_open:
  source_topology_table = json.load(topology_open)

for network, network_value in source_topology_table["ietf-network:networks"].items():
    layer3index = \
            [ i for i, value in enumerate(network_value) if value["network-id"] == "layer3" ]

for node_index, node_value \
        in enumerate(source_topology_table["ietf-network:networks"]["network"][layer3index[0]]["node"]) :
    if "seg" not in node_value["node-id"]:    
        conv_node_index = [ conv_node_index for conv_node_index, conv_node_value \
                in enumerate(source_convert_table) \
                if conv_node_value["node"]["original"] == node_value["node-id"] ]
        ## interface_description convert ##
        for if_index, if_value in enumerate(node_value["ietf-network-topology:termination-point"]):

            conv_if_index = [ conv_if_index for conv_if_index , conv_if_value in enumerate(source_convert_table[conv_node_index[0]]["iflist"]) \
                if conv_if_value["clab"] in node_value["ietf-network-topology:termination-point"][if_index]["tp-id"] ]

            if ( "mddo-topology:l3-termination-point-attributes" in  \
                    str(node_value["ietf-network-topology:termination-point"][if_index]) and \
                    "ifDescr" in source_convert_table[conv_node_index[0]]["iflist"][conv_if_index[0]] ):
                source_topology_table["ietf-network:networks"]["network"][layer3index[0]]["node"][node_index]["ietf-network-topology:termination-point"][if_index]["mddo-topology:l3-termination-point-attributes"]["description"] = source_convert_table[conv_node_index[0]]["iflist"][conv_if_index[0]]["ifDescr"]

        ## static-route interface convert (junos logic)##
        if ("interface" in str(node_value["mddo-topology:l3-node-attributes"]["static-route"])):
              for route_index, route_value in enumerate(node_value["mddo-topology:l3-node-attributes"]["static-route"]):
                  if ("dynamic"  not in str(route_value["interface"])):
                      conv_if_index = [ conv_if_index for conv_if_index , conv_if_value \
                              in enumerate(source_convert_table[conv_node_index[0]]["iflist"]) \
                              if conv_if_value["original"] in route_value["interface"] ]
                      if conv_if_index:
                          source_topology_table["ietf-network:networks"]["network"][layer3index[0]]["node"][node_index]["mddo-topology:l3-node-attributes"]["static-route"][route_index]["interface"] = "dynamic"

with open( topology_path , 'w') as topology_open:
    json.dump(source_topology_table, topology_open, indent=2, ensure_ascii=False)
