# frozen_string_literal: true

require 'netomox'
require_relative 'layer3_data_builder'
require_relative 'p_network'

# bgp_proc network data builder
class BgpProcDataBuilder < Layer3DataBuilder
  # @!attribute [r] ext_as_topology External-AS topology, contains bgp-proc/layer3
  #   @return [Netomox::PseudoDSL::PNetworks]
  attr_accessor :ext_as_topology
  alias :topology :ext_as_topology

  # @param [Symbol] as_type (enum: [source_as, :dest_as])
  # @param [String] params_file Params file path
  # @param [String] flow_data_file Flow data file path
  # @param [String] api_proxy API proxy (host:port str)
  # @param [String] network_name Network name
  def initialize(as_type, params_file, flow_data_file, api_proxy, network_name)
    super(as_type, params_file, flow_data_file, api_proxy, network_name)

    @layer3_nw = @ext_as_topology.network('layer3') # underlay network
    make_bgp_proc_topology!
  end

  private

  # @param [Netomox::PseudoDSL::PNetwork] bgp_proc_nw bgp_proc network
  # @return [void]
  # @raise [StandardError]
  def add_bgp_proc_ebgp_speakers(bgp_proc_nw)
    preferred_peer = @params['preferred_peer']

    # add ebgp-speakers
    @peer_list.each do |peer_item|
      # underlay(layer3) node/tp
      layer3_node = peer_item[:layer3][:node]
      layer3_tp = layer3_node.tps.find { |tp| tp.name == 'Ethernet0' }
      raise StandardError, "Underlay node is not found: #{layer3_node.name}[Ethernet0]" if layer3_tp.nil?

      # assign loopback ip
      loopback_ip_str = @ipam.current_loopback_ip.to_s

      # bgp-proc edge-router node
      bgp_proc_node = bgp_proc_nw.node(loopback_ip_str)
      peer_item[:bgp_proc][:node] = bgp_proc_node # memo
      bgp_proc_node.attribute = {
        router_id: loopback_ip_str,
        flags: ['ext-bgp-speaker'] # flag for external-AS BGP speaker
      }
      bgp_proc_node.supports.push(['layer3', layer3_node.name])

      # bgp-proc edge-router term-point
      bgp_proc_tp = bgp_proc_node.term_point("peer_#{peer_item[:bgp_proc][:local_ip]}")
      bgp_proc_tp.attribute = {
        local_as: peer_item[:bgp_proc][:remote_as],
        local_ip: peer_item[:bgp_proc][:remote_ip],
        remote_as: peer_item[:bgp_proc][:local_as],
        remote_ip: peer_item[:bgp_proc][:local_ip],
        flags: ["ebgp-peer=#{peer_item[:bgp_proc][:node_name]}[#{peer_item[:bgp_proc][:tp_name]}]"]
      }
      bgp_proc_tp.supports.push(['layer3', layer3_node.name, layer3_tp.name])

      # preferred peer check
      if preferred_peer
        layer3_ebgp_peer_flag = "ebgp-peer=#{preferred_peer['node']}[#{preferred_peer['interface']}]"
        if layer3_tp.attribute[:flags].include?(layer3_ebgp_peer_flag)
          warn "Warn: set preferred flag: #{@as_state[:type]}, #{bgp_proc_node.name}[#{bgp_proc_tp.name}]"
          bgp_proc_tp.attribute[:flags].push('ext-bgp-speaker-preferred')
        end
      end

      # next loopback_ip
      @ipam.count_loopback
    end
  end

  # @param [Netomox::PseudoDSL::PNode] bgp_proc_node1 bgp-proc node
  # @param [Netomox::PseudoDSL::PNode] bgp_proc_node2 bgp-proc node
  # @return [Hash]
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

  # @param [Netomox::PseudoDSL::PTermPoint] layer3_tp
  # @return [String] IP address
  def layer3_tp_addr_str(layer3_tp)
    layer3_tp.attribute[:ip_addrs][0].sub(%r{/\d+$}, '')
  end

  # @param [Netomox::PseudoDSL::PNetwork] bgp_proc_nw bgp_proc network
  # @param [Array<Hash>] peer_item_bgp_proc_pair Peer item (bgp_proc part)
  # @return [void]
  def add_bgp_proc_ibgp_links(bgp_proc_nw, peer_item_bgp_proc_pair)
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
    layer3_tp1_ip_str = layer3_tp_addr_str(layer3_edge[:node1][:tp])
    layer3_tp2_ip_str = layer3_tp_addr_str(layer3_edge[:node2][:tp])

    # node1 tp (tp1)
    bgp_proc_tp1 = bgp_proc_node1.term_point("peer_#{layer3_tp2_ip_str}")
    bgp_proc_tp1.attribute = {
      local_as: @as_state[:ext_asn],
      local_ip: layer3_tp1_ip_str,
      remote_as: @as_state[:ext_asn], # iBGP
      remote_ip: layer3_tp2_ip_str
    }
    bgp_proc_tp1.supports.push(['layer3', layer3_edge[:node1][:node].name, layer3_edge[:node1][:tp].name])

    # node2 tp (tp2)
    bgp_proc_tp2 = bgp_proc_node2.term_point("peer_#{layer3_tp1_ip_str}")
    bgp_proc_tp2.attribute = {
      local_as: @as_state[:ext_asn],
      local_ip: layer3_tp2_ip_str,
      remote_as: @as_state[:ext_asn], # iBGP
      remote_ip: layer3_tp1_ip_str
    }
    bgp_proc_tp2.supports.push(['layer3', layer3_edge[:node2][:node].name, layer3_edge[:node2][:tp].name])

    # core-edge link (bidirectional)
    bgp_proc_nw.link(bgp_proc_node1.name, bgp_proc_tp1.name, bgp_proc_node2.name, bgp_proc_tp2.name)
    bgp_proc_nw.link(bgp_proc_node2.name, bgp_proc_tp2.name, bgp_proc_node1.name, bgp_proc_tp1.name)
  end

  # @param [Netomox::PseudoDSL::PNetwork] bgp_proc_nw bgp_proc network
  # @return [Netomox::PseudoDSL::PNode] bgp_proc core router node
  def add_bgp_proc_core_router(bgp_proc_nw)
    loopback_ip_str = @ipam.current_loopback_ip.to_s
    bgp_proc_core_node = bgp_proc_nw.node(loopback_ip_str)
    bgp_proc_core_node.attribute = {
      router_id: loopback_ip_str,
      flags: ['ext-bgp-speaker'] # flag for external-AS BGP speaker
    }
    bgp_proc_core_node.supports.push(%W[layer3 as#{@as_state[:ext_asn]}-core])
    @ipam.count_loopback

    bgp_proc_core_node
  end

  # @return [void]
  def make_bgp_proc_topology!
    # bgp_proc network
    bgp_proc_nw = @ext_as_topology.network('bgp_proc')
    bgp_proc_nw.type = Netomox::NWTYPE_MDDO_BGP_PROC
    bgp_proc_nw.attribute = { name: 'mddo-bgp-network' }
    bgp_proc_nw.supports.push('layer3')

    # add core (aggregation) router
    # NOTE: assign 1st router-id for core router
    bgp_proc_core_node = add_bgp_proc_core_router(bgp_proc_nw)
    # add edge-router (ebgp speaker and inter-AS links)
    add_bgp_proc_ebgp_speakers(bgp_proc_nw)

    # iBGP mesh
    # router [] -- [tp1] Seg_x.x.x.x [tp2] -- [] router
    @peer_list.map { |peer_item| peer_item[:bgp_proc] }
              .append({ node_name: bgp_proc_core_node.name, node: bgp_proc_core_node })
              .combination(2).to_a.each do |peer_item_bgp_proc_pair|
      add_bgp_proc_ibgp_links(bgp_proc_nw, peer_item_bgp_proc_pair)
    end
  end
end
