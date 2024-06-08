# frozen_string_literal: true

require 'ipaddr'
require 'netomox'

# rubocop:disable Metrics/ClassLength

# External-AS topology builder
class ExternalASTopologyBuilder
  private

  # @param [Netomox::PseudoDSL::PNetwork] layer3_nw Layer3 network
  # @param [Array<Hash>] peer_list Peer list
  # @return [void]
  def add_layer3_ebgp_speakers(layer3_nw, peer_list)
    # add ebgp-speakers
    peer_list.each_with_index do |peer_item, peer_index|
      # inter-AS segment ip
      # NOTE: IPAddr.new("172.16.0.6/30") => #<IPAddr: IPv4:172.16.0.4/255.255.255.252>
      seg_ip = IPAddr.new(peer_item[:layer3][:ip_addr])

      # layer3 edge-router node
      node_name = format('as%<asn>s_edge%<index>02d', asn: @as_state[:ext_asn], index: peer_index + 1)
      layer3_node = layer3_nw.node(node_name)
      peer_item[:layer3][:node] = layer3_node # memo
      layer3_node.attribute = { node_type: 'node' }

      # layer3 edge-router term-point
      layer3_tp = layer3_node.term_point('Eth0')
      layer3_tp.attribute = {
        ip_addrs: ["#{peer_item[:bgp_proc][:remote_ip]}/#{seg_ip.prefix}"],
        flags: ["ebgp-peer=#{peer_item[:layer3][:node_name]}[#{peer_item[:layer3][:tp_name]}]"]
      }

      # inter-AS segment node
      layer3_seg_node = layer3_nw.node("Seg_#{seg_ip}/#{seg_ip.prefix}")
      layer3_seg_node.attribute = { node_type: 'segment', prefixes: [{ prefix: "#{seg_ip}/#{seg_ip.prefix}" }] }
      layer3_seg_tp1 = layer3_seg_node.term_point('Eth0')
      layer3_seg_tp2 = layer3_seg_node.term_point('Eth1')

      # inter-AS link, ext-as-edge to seg (bidirectional)
      layer3_nw.link(layer3_node.name, layer3_tp.name, layer3_seg_node.name, layer3_seg_tp1.name)
      layer3_nw.link(layer3_seg_node.name, layer3_seg_tp1.name, layer3_node.name, layer3_tp.name)
      # inter-AS link, seg to int-as-edge (bidirectional)
      layer3_nw.link(layer3_seg_node.name, layer3_seg_tp2.name,
                     peer_item[:layer3][:node_name], peer_item[:layer3][:tp_name])
      layer3_nw.link(peer_item[:layer3][:node_name], peer_item[:layer3][:tp_name],
                     layer3_seg_node.name, layer3_seg_tp2.name)
    end
  end

  # @param [Netomox::PseudoDSL::PNetwork] layer3_nw Layer3 network
  # @param [Netomox::PseudoDSL::PNode] layer3_core_node Layer3 core node
  # @param [Hash] peer_item Peer item (an item in peer_list with layer3/node memo)
  # @param [Integer] peer_index Index number
  # @return [void]
  def add_layer3_core_to_edge_links(layer3_nw, layer3_core_node, peer_item, peer_index)
    link_ip_str = @ipam.current_link_ip_str # network address
    link_intf_ip_str_pair = @ipam.current_link_intf_ip_str_pair # interface address pair

    # edge-router node
    layer3_edge_node = peer_item[:layer3][:node]
    # segment node
    layer3_seg_node = layer3_nw.node("Seg_#{@ipam.current_link_ip_str}")
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
    @ipam.count_link
  end

  # @param [String] flow_item Prefix (e.g. a.b.c.d/xx)
  # @return [Hash]
  def flow_addr_table(flow_item)
    seg_addr = IPAddr.new(flow_item)
    router_addr = seg_addr | '0.0.0.1'
    endpoint_addr = seg_addr | '0.0.0.100'

    {
      seg_addr: seg_addr.to_s,
      seg_addr_prefix: "#{seg_addr}/#{seg_addr.prefix}",
      router_addr: router_addr.to_s,
      router_addr_prefix: "#{router_addr}/#{router_addr.prefix}",
      endpoint_addr: endpoint_addr.to_s,
      endpoint_addr_prefix: "#{endpoint_addr}/#{endpoint_addr.prefix}"
    }
  end

  # @param [Netomox::PseudoDSL::PNetwork] layer3_nw Layer3 network
  # @param [Netomox::PseudoDSL::PNode] layer3_core_node Layer3 core node
  # @param [String] src_flow_item Flow source prefix
  # @param [Integer] src_flow_index Flow source index
  def add_layer3_core_to_endpoint_links(layer3_nw, layer3_core_node, src_flow_item, src_flow_index)
    addrs = flow_addr_table(src_flow_item)

    # endpoint node
    ep_name = format('as%<asn>s_endpoint%<index>02d', asn: @as_state[:ext_asn], index: src_flow_index)
    layer3_endpoint_node = layer3_nw.node(ep_name)
    layer3_endpoint_node.attribute = {
      node_type: 'endpoint',
      static_routes: [
        { prefix: '0.0.0.0/0', next_hop: addrs[:router_addr], interface: 'Eth0', description: 'default-route' }
      ]
    }
    # segment node
    layer3_seg_node = layer3_nw.node("Seg_#{addrs[:seg_addr_prefix]}")
    layer3_seg_node.attribute = { node_type: 'segment', prefixes: [{ prefix: addrs[:seg_addr_prefix] }] }

    # core-router tp
    core_tp_index = layer3_core_node.tps.length
    layer3_core_tp = layer3_core_node.term_point("Eth#{core_tp_index}")
    # segment_tp
    layer3_seg_tp1 = layer3_seg_node.term_point('Eth0')
    layer3_seg_tp2 = layer3_seg_node.term_point('Eth1')
    # endpoint tp
    layer3_endpoint_tp = layer3_endpoint_node.term_point('Eth0')

    # core-router tp attribute
    layer3_core_tp.attribute = { ip_addrs: [addrs[:router_addr_prefix]] }
    # endpoint tp attribute
    layer3_endpoint_tp.attribute = { ip_addrs: [addrs[:endpoint_addr_prefix]] }

    # core-seg link (bidirectional)
    layer3_nw.link(layer3_core_node.name, layer3_core_tp.name, layer3_seg_node.name, layer3_seg_tp1.name)
    layer3_nw.link(layer3_seg_node.name, layer3_seg_tp1.name, layer3_core_node.name, layer3_core_tp.name)
    # seg-endpoint link (bidirectional)
    layer3_nw.link(layer3_seg_node.name, layer3_seg_tp2.name, layer3_endpoint_node.name, layer3_endpoint_tp.name)
    layer3_nw.link(layer3_endpoint_node.name, layer3_endpoint_tp.name, layer3_seg_node.name, layer3_seg_tp2.name)
  end

  # @param [Netomox::PseudoDSL::PNetwork] layer3_nw Layer3 network
  # @return [Netomox::PseudoDSL::PNode] layer3 core router node
  def add_layer3_core_router(layer3_nw)
    layer3_core_node = layer3_nw.node("as#{@as_state[:ext_asn]}_core")
    layer3_core_node.attribute = { node_type: 'node' }
    layer3_core_node
  end

  # @return [void]
  def make_ext_as_layer3_nw!
    # layer3 network
    layer3_nw = @ext_as_topology.network('layer3')
    layer3_nw.type = Netomox::NWTYPE_MDDO_L3
    layer3_nw.attribute = { name: 'mddo-layer3-network' }

    # add core (aggregation) router
    layer3_core_node = add_layer3_core_router(layer3_nw)
    # add edge-router (ebgp speaker)
    add_layer3_ebgp_speakers(layer3_nw, @peer_list)

    # core [] -- [tp1] Seg_x.x.x.x [tp2] -- [] edge
    @peer_list.each_with_index do |peer_item, peer_index|
      add_layer3_core_to_edge_links(layer3_nw, layer3_core_node, peer_item, peer_index)
    end

    # endpoint = iperf node
    # endpoint [] -- [tp1] Seg_y.y.y.y [tp2] -- [] core
    @flow_list.each_with_index do |src_flow_item, src_flow_index|
      add_layer3_core_to_endpoint_links(layer3_nw, layer3_core_node, src_flow_item, src_flow_index)
    end
  end
end
# rubocop:enable Metrics/ClassLength
