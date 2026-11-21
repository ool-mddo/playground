# frozen_string_literal: true

# bgp_proc network data builder
class BgpProcDataBuilder < Layer3DataBuilder
  protected

  # @return [Array<Netomox::PseudoDSL::PNode>] ebgp-candidate-routers
  def find_all_bgp_proc_ebgp_candidate_routers
    @bgp_proc_nw.nodes.find_all do |node|
      node.attribute.key?(:flags) && node.attribute[:flags].include?('ebgp-candidate-router')
    end
  end

  private

  # rubocop:disable Metrics/AbcSize

  # @param [Netomox::PseudoDSL::PNode] bgp_proc_node1 bgp-proc node
  # @param [Netomox::PseudoDSL::PNode] bgp_proc_node2 bgp-proc node
  # @return [Hash] Node/tp object to connect link
  # @raise [StandardError] underlay (layer3) link not found
  def find_layer3_link_between_node(bgp_proc_node1, bgp_proc_node2)
    layer3_node1 = @layer3_nw.find_supporting_node(bgp_proc_node1)
    layer3_node2 = @layer3_nw.find_supporting_node(bgp_proc_node2)
    link = @layer3_nw.find_link_between_node(layer3_node1.name, layer3_node2.name)
    if link
      {
        node1: { node: layer3_node1, tp: @layer3_nw.node(link.src.node).term_point(link.src.tp) },
        node2: { node: layer3_node2, tp: @layer3_nw.node(link.dst.node).term_point(link.dst.tp) }
      }
    else
      link_str = "#{bgp_proc_node1.name}>#{layer3_node1.name} -- #{bgp_proc_node2.name}>#{layer3_node2.name}"
      raise StandardError, "Layer3 link not found between: #{link_str}"
    end
  end
  # rubocop:enable Metrics/AbcSize

  # @param [String] local_ip
  # @param [String] remote_ip
  # @return [Hash] bgp_proc tp attribute
  def bgp_proc_tp_ibgp_attribute(local_ip, remote_ip)
    {
      local_as: @as_state[:ext_asn],
      local_ip: local_ip,
      remote_as: @as_state[:ext_asn], # iBGP
      remote_ip: remote_ip,
      import_policies: [POLICY_PASS_ALL[:name]],
      export_policies: [POLICY_ADV_ALL_PREFIXES[:name]]
    }
  end

  # @param [Netomox::PseudoDSL::PNode] bgp_proc_node Target bgp-proc node
  # @param [String] tp_name Term-point name to add the node
  # @param [String] local_ip
  # @param [String] remote_ip
  # @param [Hash] support_layer3_edge Node/tp object to connect link ({node: PNode, tp: PTermPoint})
  # @return [Array(Netomox::PseudoDSL::PNode, Netomox::PseudoDSL::PTermPoint)] Added node/tp
  def add_bgp_proc_tp(bgp_proc_node, tp_name, local_ip, remote_ip, support_layer3_edge)
    bgp_proc_tp = bgp_proc_node.term_point(tp_name)
    bgp_proc_tp.attribute = bgp_proc_tp_ibgp_attribute(local_ip, remote_ip)
    bgp_proc_tp.supports.push([@layer3_nw.name, support_layer3_edge[:node].name, support_layer3_edge[:tp].name])

    [bgp_proc_node, bgp_proc_tp]
  end

  # add link bidirectional
  # @param [Netomox::PseudoDSL::PNode] node1
  # @param [Netomox::PseudoDSL::PTermPoint] tp1
  # @param [Netomox::PseudoDSL::PNode] node2
  # @param [Netomox::PseudoDSL::PTermPoint] tp2
  # @return [void]
  def add_bgp_proc_bdlink(node1, tp1, node2, tp2)
    @bgp_proc_nw.link(node1.name, tp1.name, node2.name, tp2.name)
    @bgp_proc_nw.link(node2.name, tp2.name, node1.name, tp1.name)
  end

  # rubocop:disable Metrics/AbcSize

  # @param [Array<Hash>] peer_item_bgp_proc_pair Peer item (bgp_proc part)
  # @return [void]
  def add_bgp_proc_ibgp_links(peer_item_bgp_proc_pair)
    # topology pattern:
    #   bgp_proc: node1 [tp1] -------------- [tp2] node2
    #               :     :                    :    :
    #   layer3:   node  [tp] -- [] seg [] -- [tp]  node
    #                        <------------->
    #                          layer3_edge (link edge info)

    # target_nodes
    bgp_proc_node1 = peer_item_bgp_proc_pair[0][:node]
    bgp_proc_node2 = peer_item_bgp_proc_pair[1][:node]

    # underlay (layer3) link/ip addr
    layer3_edge = find_layer3_link_between_node(bgp_proc_node1, bgp_proc_node2)
    tp1_ip_str = layer3_tp_addr_str(layer3_edge[:node1][:tp])
    tp2_ip_str = layer3_tp_addr_str(layer3_edge[:node2][:tp])

    # node tp
    _, bgp_proc_tp1 = add_bgp_proc_tp(bgp_proc_node1, "peer_#{tp2_ip_str}", tp1_ip_str, tp2_ip_str, layer3_edge[:node1])
    _, bgp_proc_tp2 = add_bgp_proc_tp(bgp_proc_node2, "peer_#{tp1_ip_str}", tp2_ip_str, tp1_ip_str, layer3_edge[:node2])

    # core-edge link (bidirectional)
    add_bgp_proc_bdlink(bgp_proc_node1, bgp_proc_tp1, bgp_proc_node2, bgp_proc_tp2)
  end
  # rubocop:enable Metrics/AbcSize
end
