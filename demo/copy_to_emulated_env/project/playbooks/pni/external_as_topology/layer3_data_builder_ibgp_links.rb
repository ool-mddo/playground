# frozen_string_literal: true

# Layer3 network data builder
class Layer3DataBuilder < IntASDataBuilder
  protected

  # @return [Array<Netomox::PseudoDSL::PNode>] ebgp-candidate-routers
  def find_all_layer3_ebgp_candidate_routers
    @layer3_nw.nodes.find_all do |node|
      node.attribute.key?(:flags) && node.attribute[:flags].include?('ebgp-candidate-router')
    end
  end

  private

  # @param [Netomox::PseudoDSL::PNode] layer3_node Router node
  # @param [String] link_ip_str Link (segment) ip address string
  # @return [Array(Netomox::PseudoDSL::PNode, Netomox::PseudoDSL::PTermPoint)] Added node/term-point
  def add_tp_for_inter_router_link(layer3_node, link_ip_str)
    # update node attribute
    node_attr_prefix = { prefix: link_ip_str, metric: 0, flags: ['connected'] }
    layer3_node.attribute[:prefixes] = [] unless layer3_node.attribute.key?(:prefixes)
    layer3_node.attribute[:prefixes].push(node_attr_prefix)
    # add term-point to node
    layer3_tp = layer3_node.term_point("Ethernet#{layer3_node.tps.length}")

    [layer3_node, layer3_tp]
  end

  # @param [Netomox::PseudoDSL::PTermPoint] layer3_tp Update target
  # @param [Netomox::PseudoDSL::PNode] facing_node
  # @param [Netomox::PseudoDSL::PTermPoint] facing_tp
  # @param [String] ip_addr IP address of target tp
  # @return [void]
  def update_router_tp_attributes(layer3_tp, facing_node, facing_tp, ip_addr)
    layer3_tp.attribute = {
      flags: ["ibgp-peer=#{facing_node.name}[#{facing_tp.name}]"],
      ip_addrs: [ip_addr]
    }
  end

  # @param [String] tp1_name Name of term-point1
  # @param [String] tp2_name Name of term-point2
  # @param [String] link_ip_str Link (segment) ip address string
  # @return [Array(Netomox::PseudoDSL::PNode, Netomox::PseudoDSL::PTermPoint, Netomox::PseudoDSL::PTermPoint)]
  #   Added segment node and its term-points
  def add_seg_node_tp_by_l3_pair(tp1_name, tp2_name, link_ip_str)
    layer3_seg_node = @layer3_nw.node("Seg_#{link_ip_str}")
    layer3_seg_node.attribute = {
      node_type: 'segment',
      prefixes: [{ prefix: link_ip_str, metric: 0 }]
    }
    layer3_seg_tp1 = layer3_seg_node.term_point(tp1_name)
    layer3_seg_tp2 = layer3_seg_node.term_point(tp2_name)

    [layer3_seg_node, layer3_seg_tp1, layer3_seg_tp2]
  end

  # rubocop:disable Metrics/AbcSize

  # @param [Array<Hash>] peer_item_l3_pair Peer item (layer3 part)
  # @return [void]
  def add_layer3_ibgp_links(peer_item_l3_pair)
    # topology pattern:
    #   node1 [tp1] -- [seg_tp1] seg_node [seg_tp2] -- [tp2] node2

    ipam_link_scope do |link_ip_str, link_intf_ip_str_pair|
      # target nodes/tp
      # NOTE: use ipam
      layer3_node1, layer3_tp1 = add_tp_for_inter_router_link(peer_item_l3_pair[0][:node], link_ip_str)
      layer3_node2, layer3_tp2 = add_tp_for_inter_router_link(peer_item_l3_pair[1][:node], link_ip_str)
      update_router_tp_attributes(layer3_tp1, layer3_node2, layer3_tp2, link_intf_ip_str_pair[0])
      update_router_tp_attributes(layer3_tp2, layer3_node1, layer3_tp1, link_intf_ip_str_pair[1])

      # segment node/tp
      tp1_name = "#{layer3_node1.name}_#{layer3_tp1.name}"
      tp2_name = "#{layer3_node2.name}_#{layer3_tp2.name}"
      layer3_seg_node, layer3_seg_tp1, layer3_seg_tp2 = add_seg_node_tp_by_l3_pair(tp1_name, tp2_name, link_ip_str)

      # src to seg link (bidirectional)
      add_layer3_bdlink(layer3_node1, layer3_tp1, layer3_seg_node, layer3_seg_tp1)
      # seg to dst link (bidirectional)
      add_layer3_bdlink(layer3_seg_node, layer3_seg_tp2, layer3_node2, layer3_tp2)
    end
  end
  # rubocop:enable Metrics/AbcSize
end
