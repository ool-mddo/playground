# frozen_string_literal: true

# bgp_proc network data builder
class BgpProcDataBuilder < Layer3DataBuilder
  private

  # @param [Netomox::PseudoDSL::PNode] layer3_node Layer3 node
  # @return [Array(Netomox::PseudoDSL::PNode, Netomox::PseudoDSL::PTermPoint)] found node/tp(ebgp interface)
  def find_layer3_ebgp_tp(layer3_node)
    # underlay = layer3, ebgp interface name = Ethernet0
    layer3_tp = layer3_node.tps.find { |tp| tp.name == 'Ethernet0' }
    raise StandardError, "Underlay node is not found: #{layer3_node.name}[Ethernet0]" if layer3_tp.nil?

    [layer3_node, layer3_tp]
  end

  # @param [Netomox::PseudoDSL::PNode] layer3_node Layer3 node
  # @return [String] loopback interface ip address of the node
  # @raise [StandardError] loopback is not found
  def find_layer3_loopback_tp_ip(layer3_node)
    layer3_tp = layer3_node.tps.find { |tp| tp.name == LOOPBACK_INTF_NAME }
    raise StandardError, "Loopback #{LOOPBACK_INTF_NAME} not found in #{layer3_node}" if layer3_tp.nil?

    # remove prefix length
    layer3_tp_addr_str(layer3_tp)
  end

  # @param [Hash] preferred_peer Preferred peer info from usecase params (@params['preferred_peer'])
  # @param [Netomox::PseudoDSL::PTermPoint] layer3_tp Layer3 term-point (bgp peer; facing interface)
  # @return [Boolean] true if preferred target
  def preferred_ebgp_peer?(preferred_peer, layer3_tp)
    preferred_peer &&
      layer3_tp.attribute[:flags].include?("ebgp-peer=#{preferred_peer['node']}[#{preferred_peer['interface']}]")
  end

  # @param [Hash] preferred_peer Preferred peer info from usecase params (@params['preferred_peer'])
  # @param [Netomox::PseudoDSL::PTermPoint] layer3_tp Layer3 term-point (bgp peer; facing interface)
  # @return [Array] bgp import policies
  def select_import_policies(preferred_peer, layer3_tp)
    if preferred_ebgp_peer?(preferred_peer, layer3_tp)
      [POLICY_PASS_ALL_LP200[:name]]
    else
      [POLICY_PASS_ALL[:name]]
    end
  end

  # @param [Hash] peer_item Peer item
  # @param [Hash] preferred_peer Preferred peer info from usecase params (@params['preferred_peer'])
  # @param [Netomox::PseudoDSL::PTermPoint] layer3_tp layer3 term-point (ebgp peer)
  # @return [Hash] eBGP attribute for bgp_proc term-point
  def bgp_proc_tp_ebgp_attribute(peer_item, preferred_peer, layer3_tp)
    {
      local_as: peer_item[:bgp_proc][:remote_as],
      local_ip: peer_item[:bgp_proc][:remote_ip],
      remote_as: peer_item[:bgp_proc][:local_as],
      remote_ip: peer_item[:bgp_proc][:local_ip],
      import_policies: select_import_policies(preferred_peer, layer3_tp),
      export_policies: [POLICY_ADV_ALL_PREFIXES[:name]],
      flags: ["ebgp-peer=#{peer_item[:bgp_proc][:node_name]}[#{peer_item[:bgp_proc][:tp_name]}]"]
    }
  end

  # rubocop:disable Metrics/AbcSize

  # @param [Hash] peer_item Peer item
  # @param [Netomox::PseudoDSL::PNode] layer3_node Layer3 node
  # @param [Netomox::PseudoDSL::PTermPoint] layer3_tp layer3 term-point (ebgp peer)
  # @return [Array(Netomox::PseudoDSL::PNode, Netomox::PseudoDSL::PTermPoint)] Added node/tp
  def add_bgp_proc_edge_router_node_tp(peer_item, preferred_peer, layer3_node, layer3_tp)
    # bgp-proc edge-router node
    loopback_ip_str = find_layer3_loopback_tp_ip(layer3_node)
    bgp_proc_node = @bgp_proc_nw.node(loopback_ip_str)
    peer_item[:bgp_proc][:node] = bgp_proc_node # memo
    bgp_proc_node.attribute = {
      router_id: loopback_ip_str,
      policies: DEFAULT_POLICIES
    }
    bgp_proc_node.supports.push([@layer3_nw.name, layer3_node.name])
    # bgp-proc edge-router term-point
    bgp_proc_tp = bgp_proc_node.term_point("peer_#{peer_item[:bgp_proc][:local_ip]}")
    bgp_proc_tp.attribute = bgp_proc_tp_ebgp_attribute(peer_item, preferred_peer, layer3_tp)
    bgp_proc_tp.supports.push([@layer3_nw.name, layer3_node.name, layer3_tp.name])

    [bgp_proc_node, bgp_proc_tp]
  end
  # rubocop:enable Metrics/AbcSize

  # @param [Hash] peer_item Peer-item
  # @return [void]
  # @raise [StandardError]
  def add_bgp_proc_ebgp_router(peer_item)
    # underlay(layer3) node/tp
    layer3_node, layer3_tp = find_layer3_ebgp_tp(peer_item[:layer3][:node])
    # bgp-proc edge-router node/tp
    add_bgp_proc_edge_router_node_tp(peer_item, @params['preferred_peer'], layer3_node, layer3_tp)
  end

  # @return [Netomox::PseudoDSL::PNode] bgp_proc core router node
  def add_bgp_proc_core_router
    layer3_core_node_name = layer3_router_name('core')
    loopback_ip_str = find_layer3_loopback_tp_ip(@layer3_nw.node(layer3_core_node_name))
    bgp_proc_core_node = @bgp_proc_nw.node(loopback_ip_str)
    bgp_proc_core_node.attribute = {
      router_id: loopback_ip_str,
      policies: DEFAULT_POLICIES
    }
    bgp_proc_core_node.supports.push([@layer3_nw.name, layer3_core_node_name])

    bgp_proc_core_node
  end

  # @param [Netomox::PseudoDSL::PNode] layer3_ebgp_candidate_router eBGP candidate router (layer3)
  # @return [void]
  def add_bgp_proc_ebgp_candidate_router(layer3_ebgp_candidate_router)
    loopback_ip_str = find_layer3_loopback_tp_ip(layer3_ebgp_candidate_router)

    # the node is NOT ebgp-speaker. (will be configured manually in emulated-env instance)
    #   -> it has only iBGP peer term-point as bgp-proc node (in bgp-proc network)
    bgp_proc_node = @bgp_proc_nw.node(loopback_ip_str)
    bgp_proc_node.attribute = {
      router_id: loopback_ip_str,
      policies: DEFAULT_POLICIES,
      flags: %w[ebgp-candidate-router]
    }
    bgp_proc_node.supports.push([@layer3_nw.name, layer3_ebgp_candidate_router.name])
  end
end
