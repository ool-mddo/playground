# frozen_string_literal: true

require 'netomox'
require_relative 'ip_management'

module Netomox
  module PseudoDSL
    # pseudo network
    class PNetwork
      # @param [String] node1 Node1 name
      # @param [String] node2 Node2 name
      # @return [nil, PLink]
      def find_link_between_node(node1, node2)
        # pattern:
        #   node1 [tp1] -------------------- [tp2] node2
        #   node1 [tp1] -- [] seg_node [] -- [tp2] node2
        # return: Link: node1 [tp1] -- [tp2] node2
        node1_dst_nodes = find_all_links_by_src_name(node1).map { |link| link.dst.node }
        node2_dst_nodes = find_all_links_by_src_name(node2).map { |link| link.dst.node }
        mid_nodes = node1_dst_nodes & node2_dst_nodes

        if mid_nodes.empty? && node1_dst_nodes.include?(node2) && node2_dst_nodes.include?(node1)
          # direct connected
          @links.find { |link| link.src.node == node1 && link.dst.node == node2 }
        elsif !mid_nodes.empty?
          # node-seg-node pattern
          mid_node = mid_nodes[0]
          link1 = @links.find { |link| link.src.node == node1 && link.dst.node == mid_node }
          link2 = @links.find { |link| link.src.node == mid_node && link.dst.node == node2 }
          PLink.new(link1.src, link2.dst)
        else
          # error
          nil
        end
      end

      # @param [PNode] node (upper layer node)
      # @return [PNode, nil] supported node
      def find_supporting_node(node)
        support = node.supports.find { |s| s[0] == @name }
        node(support[1])
      end
    end
  end
end

# @param [Netomox::PseudoDSL::PNetwork] bgp_proc_nw bgp_proc network
# @param [Array<Hash>] peer_list Peer list
# @return [void]
def add_bgp_proc_ebgp_speakers(bgp_proc_nw, peer_list)
  ipam = IPManagement.instance

  # add ebgp-speakers
  peer_list.each do |peer_item|
    loopback_ip_str = ipam.current_loopback_ip.to_s

    # bgp-proc edge-router node
    bgp_proc_node = bgp_proc_nw.node(loopback_ip_str)
    peer_item[:bgp_proc][:node] = bgp_proc_node # memo
    bgp_proc_node.attribute = {
      # TODO: bgp-proc node attribute
      router_id: loopback_ip_str
    }
    bgp_proc_node.supports.push(['layer3', peer_item[:layer3][:node].name])

    # bgp-proc edge-router term-point
    bgp_proc_tp = bgp_proc_node.term_point("peer_#{peer_item[:bgp_proc][:local_ip]}")
    bgp_proc_tp.attribute = {
      local_as: peer_item[:bgp_proc][:remote_as],
      local_ip: peer_item[:bgp_proc][:remote_ip],
      remote_as: peer_item[:bgp_proc][:local_as],
      remote_ip: peer_item[:bgp_proc][:local_ip],
      flags: ["ebgp-peer=#{peer_item[:bgp_proc][:node_name]}[#{peer_item[:bgp_proc][:tp_name]}]"]
    }
    bgp_proc_tp.supports.push(['layer3', peer_item[:layer3][:node].name, "Eth0"])

    # next loopback_ip
    ipam.count_loopback
  end
end

def find_layer3_link_between_node(layer3_nw, bgp_proc_node1, bgp_proc_node2)
  layer3_node1 = layer3_nw.find_supporting_node(bgp_proc_node1)
  layer3_node2 = layer3_nw.find_supporting_node(bgp_proc_node2)
  link = layer3_nw.find_link_between_node(layer3_node1.name, layer3_node2.name)
  if link
    {
      node1: { node: layer3_node1, tp: layer3_nw.node(link.src.node).term_point(link.src.tp) },
      node2: { node: layer3_node2, tp: layer3_nw.node(link.dst.node).term_point(link.dst.tp) }
    }
  else
    {}
  end
end


# @param [Netomox::PseudoDSL::PTermPoint] layer3_tp
# @return [String] IP address
def layer3_tp_addr_str(layer3_tp)
  layer3_tp.attribute[:ip_addrs][0].sub(%r{/\d+$}, '')
end

# @param [Netomox::PseudoDSL::PNetwork] layer3_nw layer3 network
# @param [Netomox::PseudoDSL::PNetwork] bgp_proc_nw bgp_proc network
# @param [Netomox::PseudoDSL::PNode] bgp_proc_core_node bgp_proc core router
# @param [Hash] peer_item Peer item (an item in peer_list with layer3/node memo)
# @return [void]
def add_bgp_proc_core_to_edge_links(layer3_nw, bgp_proc_nw, bgp_proc_core_node, peer_item)
  # edge-router node
  bgp_proc_edge_node = peer_item[:bgp_proc][:node]

  # link/ip addr
  layer3_edge = find_layer3_link_between_node(layer3_nw, bgp_proc_core_node, bgp_proc_edge_node)
  tp1_ip_str = layer3_tp_addr_str(layer3_edge[:node1][:tp])
  tp2_ip_str = layer3_tp_addr_str(layer3_edge[:node2][:tp])

  # core-router tp
  bgp_proc_core_tp = bgp_proc_core_node.term_point("peer_#{tp2_ip_str}")
  bgp_proc_core_tp.attribute = {
    local_ip: tp1_ip_str,
    remote_ip: tp2_ip_str
  }
  bgp_proc_core_tp.supports.push(['layer3', layer3_edge[:node1][:node].name, layer3_edge[:node1][:tp].name])

  # edge-router tp
  bgp_proc_edge_tp = bgp_proc_edge_node.term_point("peer_#{tp1_ip_str}")
  bgp_proc_edge_tp.attribute = {
    local_ip: tp2_ip_str,
    remote_ip: tp1_ip_str
  }
  bgp_proc_edge_tp.supports.push(['layer3', layer3_edge[:node2][:node].name, layer3_edge[:node2][:tp].name])

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
  ipam = IPManagement.instance
  loopback_ip_str = ipam.current_loopback_ip.to_s
  bgp_proc_core_node = bgp_proc_nw.node(loopback_ip_str)
  bgp_proc_core_node.attribute = {
    # TODO: bgp-proc node attribute
    router_id: loopback_ip_str
  }
  bgp_proc_core_node.supports.push(%w[layer3 PNI_core])

  # core [] -- [tp1] Seg_x.x.x.x [tp2] -- [] edge
  layer3_nw = ext_as_topology.network('layer3')
  peer_list.each do | peer_item|
    add_bgp_proc_core_to_edge_links(layer3_nw, bgp_proc_nw, bgp_proc_core_node, peer_item)
  end
end
