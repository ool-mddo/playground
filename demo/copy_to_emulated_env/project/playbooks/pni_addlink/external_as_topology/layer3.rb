# frozen_string_literal: true

require 'netomox'
require_relative 'ip_management'

# @param [Netomox::PseudoDSL::PNetwork] layer3_nw Layer3 network
# @param [Array<Hash>] peer_list Peer list
# @return [void]
def add_layer3_ebgp_speakers(layer3_nw, peer_list)
  # add ebgp-speakers
  peer_list.each_with_index do |peer_item, peer_index|
    # layer3 edge-router node
    layer3_node = layer3_nw.node(format('PNI%02d', peer_index + 1))
    peer_item[:layer3][:node] = layer3_node # memo
    layer3_node.attribute = { node_type: 'node' }

    # layer3 edge-router term-point
    layer3_tp = layer3_node.term_point('Eth0')
    layer3_tp.attribute = {
      ip_addrs: ["#{peer_item[:bgp_proc][:remote_ip]}/#{IPAddr.new(peer_item[:layer3][:ip_addr]).prefix}"],
      flags: ["ebgp-peer=#{peer_item[:layer3][:node_name]}[#{peer_item[:layer3][:tp_name]}]"]
    }
  end
end

# @param [Netomox::PseudoDSL::PNetwork] layer3_nw Layer3 network
# @param [Netomox::PseudoDSL::PNode] layer3_core_node Layer3 core node
# @param [Hash] peer_item Peer item (an item in peer_list with layer3/node memo)
# @param [Integer] peer_index Index number
# @return [void]
def add_layer3_core_to_edge_links(layer3_nw, layer3_core_node, peer_item, peer_index)
  ipam = IPManagement.instance
  link_ip_str = ipam.current_link_ip_str # network address
  link_intf_ip_str_pair = ipam.current_link_intf_ip_str_pair # interface address pair

  # edge-router node
  layer3_edge_node = peer_item[:layer3][:node]
  # segment node
  layer3_seg_node = layer3_nw.node("Seg_#{ipam.current_link_ip_str}")
  layer3_seg_node.attribute = { node_type: 'segment', prefixes: [{ prefix: link_ip_str }] }

  # core-router tp
  layer3_core_tp = layer3_core_node.term_point("Eth#{peer_index}")
  # segment tp
  layer3_seg_tp1 = layer3_seg_node.term_point('Eth0')
  layer3_seg_tp2 = layer3_seg_node.term_point('Eth1')
  # edge-router tp
  edge_tp_index = layer3_edge_node.tps.length
  layer3_edge_tp = layer3_edge_node.term_point("Eth#{edge_tp_index}")

  # core-router tp attribute
  layer3_core_tp.attribute = {
    flags: ["ibgp-peer=#{layer3_edge_node.name}[#{layer3_edge_tp.name}]"],
    ip_addrs: [link_intf_ip_str_pair[0]]
  }
  # edge-router tp attribute
  # TODO: ip address assign
  layer3_edge_tp.attribute = {
    flags: ["ibgp-peer=#{layer3_core_node.name}[#{layer3_core_tp.name}]"],
    ip_addrs: [link_intf_ip_str_pair[1]]
  }

  # core-seg link (bidirectional)
  layer3_nw.link(layer3_core_node.name, layer3_core_tp.name, layer3_seg_node.name, layer3_seg_tp1.name)
  layer3_nw.link(layer3_seg_node.name, layer3_seg_tp1.name, layer3_core_node.name, layer3_core_tp.name)
  # seg-edge link (bidirectional)
  layer3_nw.link(layer3_seg_node.name, layer3_seg_tp2.name, layer3_edge_node.name, layer3_edge_tp.name)
  layer3_nw.link(layer3_edge_node.name, layer3_edge_tp.name, layer3_seg_node.name, layer3_seg_tp2.name)

  # next link-ip
  ipam.count_link
end

# @param [Netomox::PseudoDSL::PNetwork] layer3_nw Layer3 network
# @param [Netomox::PseudoDSL::PNode] layer3_core_node Layer3 core node
# @param [Integer] src_flow_index Flow source index
def add_layer3_core_to_endpoint_links(layer3_nw, layer3_core_node, src_flow_index)
  ipam = IPManagement.instance
  link_ip_str = ipam.current_link_ip_str # network address
  link_intf_ip_pair = ipam.current_link_intf_ip_pair # interface address pair
  link_intf_ip_str_pair = ipam.current_link_intf_ip_str_pair

  # endpoint node
  layer3_endpoint_node = layer3_nw.node("iperf#{src_flow_index}")
  layer3_endpoint_node.attribute = {
    node_type: 'endpoint',
    static_routes: [
      { prefix: '0.0.0.0/0', next_hop: link_intf_ip_pair[0].to_s, interface: 'Eth0', description: 'default-route' }
    ]
  }
  # segment node
  layer3_seg_node = layer3_nw.node("Seg_#{link_ip_str}")
  layer3_seg_node.attribute = { node_type: 'segment', prefixes: [{ prefix: link_ip_str }] }

  # core-router tp
  core_tp_index = layer3_core_node.tps.length
  layer3_core_tp = layer3_core_node.term_point("Eth#{core_tp_index}")
  # segment_tp
  layer3_seg_tp1 = layer3_seg_node.term_point('Eth0')
  layer3_seg_tp2 = layer3_seg_node.term_point('Eth1')
  # endpoint tp
  layer3_endpoint_tp = layer3_endpoint_node.term_point('Eth0')

  # core-router tp attribute
  layer3_core_tp.attribute = { ip_addrs: [link_intf_ip_str_pair[0]] }
  # endpoint tp attribute
  layer3_endpoint_tp.attribute = { ip_addrs: [link_intf_ip_str_pair[1]] }

  # core-seg link (bidirectional)
  layer3_nw.link(layer3_core_node.name, layer3_core_tp.name, layer3_seg_node.name, layer3_seg_tp1.name)
  layer3_nw.link(layer3_seg_node.name, layer3_seg_tp1.name, layer3_core_node.name, layer3_core_tp.name)
  # seg-endpoint link (bidirectional)
  layer3_nw.link(layer3_seg_node.name, layer3_seg_tp2.name, layer3_endpoint_node.name, layer3_endpoint_tp.name)
  layer3_nw.link(layer3_endpoint_node.name, layer3_endpoint_tp.name, layer3_seg_node.name, layer3_seg_tp2.name)

  # next link-ip
  ipam.count_link
end

# @param [Netomox::PseudoDSL::Networks] ext_as_topology Topology object of external-AS
# @param [Array<Hash>] peer_list Peer list
# @param [Array<String>] src_flow_list Source list in flow data
# @return [void]
def make_ext_as_layer3_nw(ext_as_topology, peer_list, src_flow_list)
  # layer3 network
  layer3_nw = ext_as_topology.network('layer3')
  layer3_nw.type = Netomox::NWTYPE_MDDO_L3
  layer3_nw.attribute = { name: 'mddo-layer3-network' }

  # add edge-router (ebgp speaker)
  add_layer3_ebgp_speakers(layer3_nw, peer_list)

  # add core (aggregation) router
  layer3_core_node = layer3_nw.node('PNI_core')
  layer3_core_node.attribute = { node_type: 'node' }

  # core [] -- [tp1] Seg_x.x.x.x [tp2] -- [] edge
  peer_list.each_with_index do |peer_item, peer_index|
    add_layer3_core_to_edge_links(layer3_nw, layer3_core_node, peer_item, peer_index)
  end

  # endpoint = iperf node
  # endpoint [] -- [tp1] Seg_y.y.y.y [tp2] -- [] core
  src_flow_list.each_with_index do |_src_flow_item, src_flow_index|
    add_layer3_core_to_endpoint_links(layer3_nw, layer3_core_node, src_flow_index)
  end
end
