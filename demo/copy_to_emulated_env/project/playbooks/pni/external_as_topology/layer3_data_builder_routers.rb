# frozen_string_literal: true

# Layer3 network data builder
class Layer3DataBuilder < IntASDataBuilder
  # Loopback interface name
  LOOPBACK_INTF_NAME = 'lo0.0'

  protected

  # @param [String] suffix Router-name suffix
  # @return [String] Router-name
  def layer3_router_name(suffix)
    "as#{@as_state[:ext_asn]}-#{suffix}"
  end

  private

  # @param [IPAddr] ipaddr
  # @return [String] ip/prefix format string (e.g. "a.b.c.d/nn")
  def ipaddr_to_full_str(ipaddr)
    "#{ipaddr}/#{ipaddr.prefix}"
  end

  # @param [Netomox::PseudoDSL::PNode] layer3_node Layer3 node
  # @return [void]
  def add_loopback_to_layer3_node(layer3_node)
    ipam_loopback_scope do |loopback_ip_str|
      layer3_core_tp = layer3_node.term_point(LOOPBACK_INTF_NAME)
      layer3_core_tp.attribute = { ip_addrs: [loopback_ip_str], flags: ['loopback'] }
      # add node_prefix
      layer3_node.attribute[:prefixes] = [] unless layer3_node.attribute[:prefixes]
      layer3_node.attribute[:prefixes].unshift({ prefix: loopback_ip_str, metric: 0, flags: ['connected'] })
    end
  end

  # @return [Netomox::PseudoDSL::PNode] layer3 core router node
  def add_layer3_core_router
    # node
    layer3_core_node = @layer3_nw.node(layer3_router_name('core'))
    layer3_core_node.attribute = { node_type: 'node' }
    # term-point (loopback)
    add_loopback_to_layer3_node(layer3_core_node)

    layer3_core_node
  end

  # rubocop:disable Metrics/AbcSize

  # @param [Hash] peer_item Peer-item
  # @param [Integer] peer_index
  # @param [IPAddr] segment_ip IP address of eBGP (inter-AS) link segment
  # @return [void]
  def add_layer3_edge_router_node_tp(peer_item, peer_index, segment_ip)
    # node
    node_name = layer3_router_name(format('edge%02d', peer_index + 1))
    layer3_node = @layer3_nw.node(node_name)
    layer3_node.attribute = {
      node_type: 'node',
      prefixes: [{ prefix: "#{segment_ip}/#{segment_ip.prefix}", metric: 0, flags: ['connected'] }]
    }
    # term-point (loopback)
    add_loopback_to_layer3_node(layer3_node)
    # term-point (eBGP interface)
    layer3_tp = layer3_node.term_point('Ethernet0')
    layer3_tp.attribute = {
      ip_addrs: ["#{peer_item[:bgp_proc][:remote_ip]}/#{segment_ip.prefix}"],
      flags: ["ebgp-peer=#{peer_item[:layer3][:node_name]}[#{peer_item[:layer3][:tp_name]}]"]
    }

    # memo to peer_item
    peer_item[:layer3][:node] = layer3_node
  end
  # rubocop:enable Metrics/AbcSize

  # @param [Hash] peer_item Peer-item
  # @param [Integer] peer_index
  # @return [void]
  def add_layer3_edge_router(peer_item, peer_index)
    # inter-AS segment ip
    # NOTE: IPAddr.new("172.16.0.6/30") => #<IPAddr: IPv4:172.16.0.4/255.255.255.252>
    segment_ip = IPAddr.new(peer_item[:layer3][:ip_addr])

    # layer3 edge-router node/tp
    add_layer3_edge_router_node_tp(peer_item, peer_index, segment_ip)
  end

  # @param [Hash] add_link One of a parameter from @params['add_links']
  # @param [IPAddr] link_segment_ip IP Address of eBGP link segment
  # @return [Array(Netomox::PseudoDSL::PNode, Netomox::PseudoDSL::PTermPoint)] Added node/tp
  def add_layer3_ext_as_candidate_node_tp(add_link, link_segment_ip)
    # node
    layer3_ext_node = @layer3_nw.node(layer3_router_name(format('edge%02d', @layer3_nw.nodes.length)))
    layer3_ext_node.attribute = {
      node_type: 'node',
      prefixes: [{ prefix: ipaddr_to_full_str(link_segment_ip), metric: 0, flags: ['connected'] }],
      flags: ['ebgp-candidate-router']
    }
    # term-point (loopback)
    add_loopback_to_layer3_node(layer3_ext_node)
    # term-point (eBGP interface)
    layer3_ext_tp = layer3_ext_node.term_point("Ethernet#{layer3_ext_node.tps.length}")
    layer3_ext_tp.attribute = {
      ip_addrs: ["#{add_link['remote_ip']}/#{link_segment_ip.prefix}"],
      flags: ["ebgp-peer=#{add_link['node']}[#{add_link['interface']}]", 'ebgp-candidate-interface']
    }

    [layer3_ext_node, layer3_ext_tp]
  end

  # @param [Hash] add_link One of a parameter from @params['add_links']
  # @return [Array(Netomox::Topology::Node, Netomox::Topology::TermPoint)] found node/tp
  # @raise [StandardError] Node or term-point is not found
  def find_layer3_int_as_edge_node_tp(add_link)
    # internal edge router
    layer3_int_nw = @int_as_topology.find_network(@layer3_nw.name)
    layer3_int_node = layer3_int_nw.find_node_by_name(add_link['node'])
    raise StandardError, "Internal-AS edge-node:#{add_link['node']} to add is not found" if layer3_int_node.nil?

    layer3_int_tp = layer3_int_node.find_tp_by_name(add_link['interface'])
    raise StandardError, "Internal-AS edge-tp:#{add_link['interface']} to add is not found" if layer3_int_tp.nil?

    [layer3_int_node, layer3_int_tp]
  end

  # @param [Netomox::Topology::Node] layer3_int_node Internal-AS node
  # @param [Netomox::Topology::TermPoint] layer3_int_tp Internal-AS term-point
  # @param [Hash] add_link One of a parameter from @params['add_links']
  # @return [IPAddr] Network address of inter-AS link (segment)
  # @raise [StandardError] Mismatch between add_link params and term-point address
  def inter_as_link_segment_ip(layer3_int_node, layer3_int_tp, add_link)
    link_seg_ip = IPAddr.new(layer3_int_tp.attribute[:ip_addrs][0])
    unless link_seg_ip.include?(add_link['remote_ip'])
      int_node = "#{layer3_int_node.name}[#{layer3_int_tp.name}]"
      raise StandardError,
            "Remote-IP:#{add_link['remote_ip']} is not included in IP:#{link_seg_ip} at #{int_node}"
    end
    link_seg_ip
  end

  # @param [String] tp1_name Name of term-point1
  # @param [String] tp2_name Name of term-point2
  # @param [IPAddr] link_segment_ip Segment network address
  # @return [Array(Netomox::PseudoDSL::PNode, Netomox::PseudoDSL::PTermPoint, Netomox::PseudoDSL::PTermPoint)]
  #   Added segment node and its term-points
  def add_layer3_inter_as_seg_node_tp(tp1_name, tp2_name, link_segment_ip)
    prefix_str = ipaddr_to_full_str(link_segment_ip)
    seg_node = @layer3_nw.node("Seg_#{prefix_str}")
    seg_node.attribute = {
      node_type: 'segment',
      prefixes: [{ prefix: prefix_str, metric: 0 }]
    }
    seg_tp1 = seg_node.term_point(tp1_name)
    seg_tp2 = seg_node.term_point(tp2_name)

    [seg_node, seg_tp1, seg_tp2]
  end

  # @param [Netomox::Topology::Node] layer3_int_node
  # @param [Netomox::Topology::TermPoint] layer3_int_tp
  # @param [Netomox::PseudoDSL::PNode] layer3_ext_node
  # @param [Netomox::PseudoDSL::PTermPoint] layer3_ext_tp
  # @param [IPAddr] link_segment_ip
  def add_layer3_inter_as_link(layer3_int_node, layer3_int_tp, layer3_ext_node, layer3_ext_tp, link_segment_ip)
    # pattern:
    #   int-as-edge [] -- [tp1] seg [tp2] -- [] ext-as-edge
    tp1_name = "#{layer3_int_node.name}_#{layer3_int_tp.name}"
    tp2_name = "#{layer3_ext_node.name}_#{layer3_ext_tp.name}"
    seg_node, seg_tp1, seg_tp2 = add_layer3_inter_as_seg_node_tp(tp1_name, tp2_name, link_segment_ip)
    # int-as-edge -- seg
    add_layer3_bdlink(layer3_int_node, layer3_int_tp, seg_node, seg_tp1)
    # seg -- ext-as-edge
    add_layer3_bdlink(seg_node, seg_tp2, layer3_ext_node, layer3_ext_tp)
  end

  # @param [Hash] add_link A link info to add (internal-AS edge interface)
  # @return [void]
  def add_layer3_ebgp_candidate_router(add_link)
    layer3_int_node, layer3_int_tp = find_layer3_int_as_edge_node_tp(add_link)
    link_segment_ip = inter_as_link_segment_ip(layer3_int_node, layer3_int_tp, add_link)

    # external edge router
    layer3_ext_node, layer3_ext_tp = add_layer3_ext_as_candidate_node_tp(add_link, link_segment_ip)

    # links (inter-AS links)
    # NOTICE: Usually, inter-AS links are added later by the splice API.
    #   However, this is done based on the inter-AS interface information defined in the bgp_as layer.
    #   Therefore, L3 interface information of candidate routers for which BGP is not configured is not added.
    #   Inter-AS link information is added here beforehand.
    add_layer3_inter_as_link(layer3_int_node, layer3_int_tp, layer3_ext_node, layer3_ext_tp, link_segment_ip)
  end
end
