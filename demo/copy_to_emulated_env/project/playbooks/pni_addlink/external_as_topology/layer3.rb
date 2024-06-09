# frozen_string_literal: true

require 'ipaddr'
require 'netomox'

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
      node_name = format('as%<asn>s-edge%<index>02d', asn: @as_state[:ext_asn], index: peer_index + 1)
      layer3_node = layer3_nw.node(node_name)
      peer_item[:layer3][:node] = layer3_node # memo
      layer3_node.attribute = { node_type: 'node' }

      # layer3 edge-router term-point
      layer3_tp = layer3_node.term_point('Ethernet0')
      layer3_tp.attribute = {
        ip_addrs: ["#{peer_item[:bgp_proc][:remote_ip]}/#{seg_ip.prefix}"],
        flags: ["ebgp-peer=#{peer_item[:layer3][:node_name]}[#{peer_item[:layer3][:tp_name]}]"]
      }
    end
  end

  # @param [Netomox::PseudoDSL::PNetwork] layer3_nw Layer3 network
  # @param [Array<Hash>] peer_item_l3_pair Peer item (layer3 part)
  # @return [void]
  def add_layer3_ibgp_links(layer3_nw, peer_item_l3_pair)
    link_ip_str = @ipam.current_link_ip_str # network address
    link_intf_ip_str_pair = @ipam.current_link_intf_ip_str_pair # interface address pair

    # topology pattern:
    #   node1 [tp1] -- [seg_tp1] seg_node [seg_tp2] -- [tp2] node2

    # target nodes/tp
    layer3_node1 = peer_item_l3_pair[0][:node]
    layer3_tp1 = layer3_node1.term_point("Ethernet#{layer3_node1.tps.length}")
    layer3_node2 = peer_item_l3_pair[1][:node]
    layer3_tp2 = layer3_node2.term_point("Ethernet#{layer3_node2.tps.length}")

    # segment node/tp
    layer3_seg_node = layer3_nw.node("Seg_#{@ipam.current_link_ip_str}")
    layer3_seg_node.attribute = { node_type: 'segment', prefixes: [{ prefix: link_ip_str }] }
    layer3_seg_tp1 = layer3_seg_node.term_point("#{layer3_node1.name}_#{layer3_tp1.name}")
    layer3_seg_tp2 = layer3_seg_node.term_point("#{layer3_node2.name}_#{layer3_tp2.name}")

    # target tp attribute
    layer3_tp1.attribute = {
      flags: ["ibgp-peer=#{layer3_node2.name}[#{layer3_tp2.name}]"],
      ip_addrs: [link_intf_ip_str_pair[0]]
    }
    layer3_tp2.attribute = {
      flags: ["ibgp-peer=#{layer3_node1.name}[#{layer3_tp1.name}]"],
      ip_addrs: [link_intf_ip_str_pair[1]]
    }

    # src to seg link (bidirectional)
    layer3_nw.link(layer3_node1.name, layer3_tp1.name, layer3_seg_node.name, layer3_seg_tp1.name)
    layer3_nw.link(layer3_seg_node.name, layer3_seg_tp1.name, layer3_node1.name, layer3_tp1.name)
    # seg to dst link (bidirectional)
    layer3_nw.link(layer3_seg_node.name, layer3_seg_tp2.name, layer3_node2.name, layer3_tp2.name)
    layer3_nw.link(layer3_node2.name, layer3_tp2.name, layer3_seg_node.name, layer3_seg_tp2.name)

    # next link-ip
    @ipam.count_link
  end

  # @param [String] flow_item Prefix (e.g. a.b.c.d/xx)
  # @return [Hash]
  # @raise [StandardError] Endpoint segment is too small
  def flow_addr_table(flow_item)
    seg_addr = IPAddr.new(flow_item)
    raise StandardError, "Endpoint segment is too small (>/25), #{flow_item}" if seg_addr.prefix > 25

    router_addr = seg_addr | '0.0.0.1'
    endpoint_addr = seg_addr | '0.0.0.100' # MUST prefix <= /25

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

    # topology pattern:
    #   endpoint [tp] -- [seg_tp1] seg_node [seg_tp2] -- [tp] core

    # core tp
    core_tp_index = layer3_core_node.tps.length
    layer3_core_tp = layer3_core_node.term_point("Ethernet#{core_tp_index}")
    layer3_core_tp.attribute = { ip_addrs: [addrs[:router_addr_prefix]] }

    # endpoint node/tp
    ep_name = format('as%<asn>s-endpoint%<index>02d', asn: @as_state[:ext_asn], index: src_flow_index)
    layer3_endpoint_node = layer3_nw.node(ep_name)
    layer3_endpoint_node.attribute = {
      node_type: 'endpoint',
      static_routes: [
        { prefix: '0.0.0.0/0', next_hop: addrs[:router_addr], interface: 'Ethernet0', description: 'default-route' }
      ]
    }
    layer3_endpoint_tp = layer3_endpoint_node.term_point('Ethernet0')
    layer3_endpoint_tp.attribute = { ip_addrs: [addrs[:endpoint_addr_prefix]] }

    # segment node/tp
    layer3_seg_node = layer3_nw.node("Seg_#{addrs[:seg_addr_prefix]}")
    layer3_seg_node.attribute = { node_type: 'segment', prefixes: [{ prefix: addrs[:seg_addr_prefix] }] }
    layer3_seg_tp1 = layer3_seg_node.term_point("#{layer3_core_node.name}_#{layer3_core_tp.name}")
    layer3_seg_tp2 = layer3_seg_node.term_point("#{layer3_endpoint_node.name}_#{layer3_endpoint_tp.name}")

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
    layer3_core_node = layer3_nw.node("as#{@as_state[:ext_asn]}-core")
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
    # add edge-router (ebgp speaker and inter-AS links)
    add_layer3_ebgp_speakers(layer3_nw, @peer_list)

    # iBGP mesh
    # router [] -- [tp1] Seg_x.x.x.x [tp2] -- [] router
    @peer_list.map { |peer_item| peer_item[:layer3] }
              .append({ node_name: layer3_core_node.name, node: layer3_core_node })
              .combination(2).to_a.each do |peer_item_l3_pair|
      add_layer3_ibgp_links(layer3_nw, peer_item_l3_pair)
    end

    # endpoint = iperf node
    # endpoint [] -- [tp1] Seg_y.y.y.y [tp2] -- [] core
    @flow_list.each_with_index do |src_flow_item, src_flow_index|
      add_layer3_core_to_endpoint_links(layer3_nw, layer3_core_node, src_flow_item, src_flow_index)
    end
  end
end
