# frozen_string_literal: true

require 'netomox'

# @param [Netomox::PseudoDSL::PNetwork] bgp_proc_nw bgp_proc network
# @param [Array<Hash>] peer_list Peer list
# @return [void]
def add_bgp_proc_ebgp_speakers(bgp_proc_nw, peer_list)
  # add ebgp-speakers
  peer_list.each_with_index do |peer_item, peer_index|
    # bgp-proc edge-router node
    bgp_proc_node = bgp_proc_nw.node(sprintf("PNI%02d_bgp", peer_index + 1))
    peer_item[:bgp_proc][:node] = bgp_proc_node # memo
    # TODO: bgp-proc node attribute (router-id assign)
    bgp_proc_node.attribute = {
      router_id: 'x.x.x.x'
    }
    bgp_proc_node.supports.push(['layer3', peer_item[:layer3][:node].name])

    # bgp-proc edge-router term-point
    bgp_proc_tp = bgp_proc_node.term_point("peer_#{peer_item[:bgp_proc][:local_ip]}")
    bgp_proc_tp.attribute = {
      local_as: peer_item[:bgp_proc][:remote_as],
      local_ip: peer_item[:bgp_proc][:remote_ip],
      remote_as: peer_item[:bgp_proc][:local_as],
      remote_ip: peer_item[:bgp_proc][:local_ip],
      flags: ["ebgp-peer=#{peer_item[:layer3][:node_name]}[#{peer_item[:layer3][:tp_name]}]"]
    }
    bgp_proc_tp.supports.push(['layer3', peer_item[:layer3][:node].name, "Eth0"])
  end
end

# @param [Netomox::PseudoDSL::PNetwork] bgp_proc_nw bgp_proc network
# @param [Netomox::PseudoDSL::PNode] bgp_proc_core_node bgp_proc core router
# @param [Hash] peer_item Peer item (an item in peer_list with layer3/node memo)
# @param [Integer] peer_index Index number
# @return [void]
def add_bgp_proc_core_to_edge_links(bgp_proc_nw, bgp_proc_core_node, peer_item, peer_index)
  # edge-router node
  bgp_proc_edge_node = peer_item[:bgp_proc][:node]

  # core-router tp
  # TODO: peer ip assign
  bgp_proc_core_tp = bgp_proc_core_node.term_point("peer_x.x.x#{peer_index}")
  # TODO: bgp_proc_core_tp.attribute = {...}
  # TODO: bgp_proc_core_tp.supports.push(['layer3', ...])
  # edge-router tp
  bgp_proc_edge_tp = bgp_proc_edge_node.term_point("peer_x.x.y#{peer_index}")
  # TODO: bgp_proc_edge_tp.attribute = {...}
  # TODO: bgp_proc_edge_tp.supports.push(['layer3', ...])

  # core-edge link (bidirectional)
  bgp_proc_nw.link(bgp_proc_core_node.name, bgp_proc_core_tp.name, bgp_proc_edge_node.name, bgp_proc_edge_tp.name)
  bgp_proc_nw.link(bgp_proc_edge_node.name, bgp_proc_edge_tp.name, bgp_proc_core_node.name, bgp_proc_core_tp.name)
end

# @param [Netomox::PseudoDSL::Networks] ext_as_topology Topology object of external-AS
# @param [Array<Hash>] peer_list Peer list
# @return [void]
def make_ext_as_bgp_proc_nw(ext_as_topology, peer_list)
  # bgp_proc network
  bgp_proc_nw = ext_as_topology.network('bgp_proc')
  bgp_proc_nw.type = Netomox::NWTYPE_MDDO_BGP_PROC
  bgp_proc_nw.attribute = { name: 'mddo-bgp-network' }

  # add edge-router (ebgp speaker)
  add_bgp_proc_ebgp_speakers(bgp_proc_nw, peer_list)

  # add core (aggregation) router
  # TODO: node-name assign (router-id)
  bgp_proc_core_node = bgp_proc_nw.node('PNI_core_bgp')
  # TODO: bgp_proc_core_node.attribute = {...}
  bgp_proc_core_node.supports.push(%w[layer3 PNI_core])

  # core [] -- [tp1] Seg_x.x.x.x [tp2] -- [] edge
  peer_list.each_with_index do | peer_item, peer_index|
    add_bgp_proc_core_to_edge_links(bgp_proc_nw, bgp_proc_core_node, peer_item, peer_index)
  end
end
