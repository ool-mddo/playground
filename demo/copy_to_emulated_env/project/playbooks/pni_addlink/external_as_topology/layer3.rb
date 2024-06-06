# frozen_string_literal: true

require 'netomox'

# @param [Netomox::PseudoDSL::PNetwork] layer3_nw Layer3 network
# @param [Array<Hash>] peer_list Peer list
# @return [void]
def add_ebgp_speakers(layer3_nw, peer_list)
  # add ebgp-speakers
  peer_list.each_with_index do |peer_item, node_index|
    layer3_node = layer3_nw.node(sprintf("PNI%02d", node_index + 1))
    peer_item[:layer3][:node] = layer3_node # memo
    layer3_node.attribute = { node_type: 'node' }
    layer3_tp = layer3_node.term_point("Eth0")
    layer3_tp.attribute = {
      ip_addrs: ["#{peer_item[:bgp_proc][:remote_ip]}/30"], # TODO subnet-mask
      flags: ["ebgp-peer=#{peer_item[:layer3][:node_name]}[#{peer_item[:layer3][:tp_name]}]"]
    }
  end
end

# @param [Netomox::PseudoDSL::PNetwork] layer3_nw Layer3 network
# @param [Netomox::PseudoDSL::PNode] layer3_core_node Layer3 core node
# @param [Hash] peer_item Peer item (an item in peer_list with layer3/node memo)
# @param [Integer] peer_index Index number
# @return [void]
def add_core_to_edge_links(layer3_nw, layer3_core_node, peer_item, peer_index)
  # edge-router node
  layer3_edge_node = peer_item[:layer3][:node]
  # segment node
  # TODO: segment address assign (/30)
  layer3_seg_node = layer3_nw.node("Seg_x#{peer_index}")
  layer3_seg_node.attribute = { node_type: 'segment', prefixes: [{ prefix: 'x.x.x.x/xx', metric: 0 }] }

  # core-router tp
  layer3_core_tp = layer3_core_node.term_point("Eth#{peer_index}")
  # segment tp
  layer3_seg_tp1 = layer3_seg_node.term_point("Eth0")
  layer3_seg_tp2 = layer3_seg_node.term_point("Eth1")
  # edge-router tp
  edge_tp_index = layer3_edge_node.tps.length
  layer3_edge_tp = layer3_edge_node.term_point("Eth#{edge_tp_index}")

  # core-router tp attribute
  # TODO: ip address assign
  layer3_core_tp.attribute = {
    flags: ["ibgp-peer=#{layer3_edge_node.name}[#{layer3_edge_tp.name}]"],
    ip_addrs: [ 'x.x.x.1' ]
  }
  # edge-router tp attribute
  # TODO: ip address assign
  layer3_edge_tp.attribute = {
    flags: ["ibgp-peer=#{layer3_core_node.name}[#{layer3_core_tp.name}]"],
    ip_addrs: [ 'x.x.x.2' ]
  }

  # core-seg link (bidirectional)
  layer3_nw.link(layer3_core_node.name, layer3_core_tp.name, layer3_seg_node.name, layer3_seg_tp1.name)
  layer3_nw.link(layer3_seg_node.name, layer3_seg_tp1.name, layer3_core_node.name, layer3_core_tp.name)
  # seg-edge link (bidirectional)
  layer3_nw.link(layer3_seg_node.name, layer3_seg_tp2.name, layer3_edge_node.name, layer3_edge_tp.name)
  layer3_nw.link(layer3_edge_node.name, layer3_edge_tp.name, layer3_seg_node.name, layer3_seg_tp2.name)
end

# @param [Netomox::PseudoDSL::PNetwork] layer3_nw Layer3 network
# @param [Netomox::PseudoDSL::PNode] layer3_core_node Layer3 core node
# @param [String] flow_src_item Flow source
# @param [Integer] flow_src_index Flow source index
def add_core_to_endpoint_links(layer3_nw, layer3_core_node, flow_src_item, flow_src_index)
  # endpoint node
  layer3_endpoint_node = layer3_nw.node("iperf#{flow_src_index}")
  layer3_endpoint_node.attribute = {
    node_type: 'endpoint',
    static_routes: [{ prefix: 'y.y.y.y/yy', next_hop: 'y.y.y.1', interface: 'Eth0' }]
  }
  # segment node
  # TODO: segment address assign
  layer3_seg_node = layer3_nw.node("Seg_y#{flow_src_index}")
  layer3_seg_node.attribute = { node_type: 'segment', prefixes: [{ prefix: 'y.y.y.y/yy', metric: 0 }] }

  # core-router tp
  core_tp_index = layer3_core_node.tps.length
  layer3_core_tp = layer3_core_node.term_point("Eth#{core_tp_index}")
  # segment_tp
  layer3_seg_tp1 = layer3_seg_node.term_point("Eth0")
  layer3_seg_tp2 = layer3_seg_node.term_point("Eth1")
  # endpoint tp
  layer3_endpoint_tp = layer3_endpoint_node.term_point('Eth0')

  # core-router tp attribute
  # TODO: ip address assign
  layer3_core_tp.attribute = {
    ip_addrs: [ 'y.y.y.1' ]
  }
  # endpoint tp attribute
  # TODO: ip address assign
  layer3_endpoint_tp.attribute = {
    ip_addrs: [ 'y.y.y.2' ]
  }

  # core-seg link (bidirectional)
  layer3_nw.link(layer3_core_node.name, layer3_core_tp.name, layer3_seg_node.name, layer3_seg_tp1.name)
  layer3_nw.link(layer3_seg_node.name, layer3_seg_tp1.name, layer3_core_node.name, layer3_core_tp.name)
  # seg-endpoint link (bidirectional)
  layer3_nw.link(layer3_seg_node.name, layer3_seg_tp2.name, layer3_endpoint_node.name, layer3_endpoint_tp.name)
  layer3_nw.link(layer3_endpoint_node.name, layer3_endpoint_tp.name, layer3_seg_node.name, layer3_seg_tp2.name)
end

# @param [Netomox::PseudoDSL::Networks] ext_as_topology Topology object of external-AS
# @param [Array<Hash>] peer_list Peer list
# @param [Array<String>] flow_src_list Source list in flow data
# @return [void]
def make_ext_as_layer3_nw(ext_as_topology, peer_list, flow_src_list)
  # layer3 network
  layer3_nw = ext_as_topology.network('layer3')
  layer3_nw.type = Netomox::NWTYPE_MDDO_L3
  layer3_nw.attribute = { name: 'mddo-layer3-network' }
  add_ebgp_speakers(layer3_nw, peer_list)

  # add core (aggregation) router
  layer3_core_node = layer3_nw.node('PNI_core')
  layer3_core_node.attribute = { node_type: 'node'}
  # core [] -- [tp1] Seg_x.x.x.x [tp2] -- [] edge
  peer_list.each_with_index do |peer_item, peer_index|
    add_core_to_edge_links(layer3_nw, layer3_core_node, peer_item, peer_index)
  end
  # endpoint = iperf node
  # endpoint [] -- [tp1] Seg_y.y.y.y [tp2] -- [] core
  flow_src_list.each_with_index do |flow_src_item, flow_src_index|
    add_core_to_endpoint_links(layer3_nw, layer3_core_node, flow_src_item, flow_src_index)
  end
end
