# frozen_string_literal: true

# Layer3 network data builder
class Layer3DataBuilder < IntASDataBuilder
  private

  # @param [String] flow_prefix Prefix (e.g. a.b.c.d/xx)
  # @return [Hash] Segment ip address table
  # @raise [StandardError] Endpoint segment is too small
  def flow_addr_table(flow_prefix)
    seg_addr = IPAddr.new(flow_prefix)
    raise StandardError, "Endpoint segment is too small (>/25), #{flow_prefix}" if seg_addr.prefix > 25

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

  # @param [Netomox::PseudoDSL::PNode] layer3_core_node Core router
  # @param [Hash] addrs Segment ip address table
  # @return [Array(Netomox::PseudoDSL::PNode, Netomox::PseudoDSL::PTermPoint)] Added node/tp
  def add_core_node_tp_for_endpoint(layer3_core_node, addrs)
    node_attr_prefix = { prefix: addrs[:seg_addr_prefix], metric: 0, flags: ['connected'] }
    # update node attribute
    layer3_core_node.attribute[:prefixes] = [] unless layer3_core_node.attribute.key?(:prefixes)
    layer3_core_node.attribute[:prefixes].push(node_attr_prefix)
    # add term-point to connect endpoint
    core_tp_index = layer3_core_node.tps.length
    layer3_core_tp = layer3_core_node.term_point("Ethernet#{core_tp_index}")
    layer3_core_tp.attribute = { ip_addrs: [addrs[:router_addr_prefix]] }

    [layer3_core_node, layer3_core_tp]
  end

  # @param [String] ep_name Endpoint node name
  # @param [Hash] addrs Segment ip address table
  # @return [Array(Netomox::PseudoDSL::PNode, Netomox::PseudoDSL::PTermPoint)] Added node/tp
  def add_layer3_endpoint_node_tp(ep_name, addrs)
    node_attr_prefix = { prefix: addrs[:seg_addr_prefix], metric: 0, flags: ['connected'] }
    # node
    layer3_endpoint_node = @layer3_nw.node(ep_name)
    layer3_endpoint_node.attribute = {
      node_type: 'endpoint',
      static_routes: [
        { prefix: '0.0.0.0/0', next_hop: addrs[:router_addr], interface: 'Ethernet0', description: 'default-route' }
      ],
      prefixes: [node_attr_prefix]
    }
    # term-point
    layer3_endpoint_tp = layer3_endpoint_node.term_point('Ethernet0')
    layer3_endpoint_tp.attribute = { ip_addrs: [addrs[:endpoint_addr_prefix]] }

    [layer3_endpoint_node, layer3_endpoint_tp]
  end

  # @param [String] tp1_name Name of term-point1
  # @param [String] tp2_name Name of term-point2
  # @param [Hash] addrs Segment ip address table
  # @return [Array(Netomox::PseudoDSL::PNode, Netomox::PseudoDSL::PTermPoint, Netomox::PseudoDSL::PTermPoint)]
  #   Added segment node and its term-points
  def add_layer3_inter_endpoint_seg_node_tp(tp1_name, tp2_name, addrs)
    seg_attr_prefix = { prefix: addrs[:seg_addr_prefix], metric: 0 }
    # node
    layer3_seg_node = @layer3_nw.node("Seg_#{addrs[:seg_addr_prefix]}")
    layer3_seg_node.attribute = { node_type: 'segment', prefixes: [seg_attr_prefix] }
    # term-point
    layer3_seg_tp1 = layer3_seg_node.term_point(tp1_name)
    layer3_seg_tp2 = layer3_seg_node.term_point(tp2_name)

    [layer3_seg_node, layer3_seg_tp1, layer3_seg_tp2]
  end

  # @param [Netomox::PseudoDSL::PNode] layer3_core_node Layer3 core node
  # @param [String] flow_prefix Flow prefix (e.g. a.b.c.d/xx)
  # @param [Integer] flow_index Flow index
  def add_layer3_core_to_endpoint_links(layer3_core_node, flow_prefix, flow_index)
    addrs = flow_addr_table(flow_prefix)

    # topology pattern:
    #   endpoint [tp] -- [seg_tp1] seg_node [seg_tp2] -- [tp] core

    # core node-attr/tp
    _, layer3_core_tp = add_core_node_tp_for_endpoint(layer3_core_node, addrs)

    # endpoint node/tp
    ep_name = layer3_router_name(format('endpoint%02d', flow_index))
    layer3_ep_node, layer3_ep_tp = add_layer3_endpoint_node_tp(ep_name, addrs)

    # segment node/tp
    tp1_name = "#{layer3_core_node.name}_#{layer3_core_tp.name}"
    tp2_name = "#{layer3_ep_node.name}_#{layer3_ep_tp.name}"
    layer3_seg_node, layer3_seg_tp1, layer3_seg_tp2 = add_layer3_inter_endpoint_seg_node_tp(tp1_name, tp2_name, addrs)

    # core-seg link (bidirectional)
    add_layer3_bdlink(layer3_core_node, layer3_core_tp, layer3_seg_node, layer3_seg_tp1)
    # seg-endpoint link (bidirectional)
    add_layer3_bdlink(layer3_seg_node, layer3_seg_tp2, layer3_ep_node, layer3_ep_tp)
  end
end
