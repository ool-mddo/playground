# frozen_string_literal: true

require 'netomox'

require_relative 'layer3_data_builder'
require_relative 'p_network'
require_relative 'bgp_proc_data_builder_routers'
require_relative 'bgp_proc_data_builder_ibgp_links'

# bgp_proc network data builder
class BgpProcDataBuilder < Layer3DataBuilder
  # @!attribute [r] ext_as_topology External-AS topology, contains bgp-proc/layer3
  #   @return [Netomox::PseudoDSL::PNetworks]
  attr_accessor :ext_as_topology

  # external-AS bgp node default policies
  POLICY_ADV_ALL_PREFIXES = {
    name: 'advertise-all-prefixes',
    statements: [
      { name: 10, conditions: [{ rib: 'inet.0' }], actions: [{ target: 'accept' }] }
    ]
  }.freeze
  POLICY_PASS_ALL = {
    name: 'pass-all',
    default: { actions: [{ target: 'accept' }] }
  }.freeze
  POLICY_PASS_ALL_LP200 = {
    name: 'pass-all-lp200',
    default: { actions: [{ local_preference: 200 }, { target: 'accept' }] }
  }.freeze
  DEFAULT_POLICIES = [POLICY_ADV_ALL_PREFIXES, POLICY_PASS_ALL, POLICY_PASS_ALL_LP200].freeze

  # @param [Symbol] as_type (enum: [source_as, :dest_as])
  # @param [String] params_file Params file path
  # @param [String] flow_data_file Flow data file path
  # @param [String] api_proxy API proxy (host:port str)
  # @param [String] network_name Network name
  def initialize(as_type, params_file, flow_data_file, api_proxy, network_name)
    super(as_type, params_file, flow_data_file, api_proxy, network_name)

    # bgp_proc network
    @bgp_proc_nw = @ext_as_topology.network('bgp_proc')
    @bgp_proc_nw.type = Netomox::NWTYPE_MDDO_BGP_PROC
    @bgp_proc_nw.attribute = { name: 'mddo-bgp-network' }
    @bgp_proc_nw.supports.push(@layer3_nw.name)

    make_bgp_proc_topology!
  end

  private

  # @param [Netomox::PseudoDSL::PTermPoint] layer3_tp
  # @return [String] IP address
  def layer3_tp_addr_str(layer3_tp)
    layer3_tp.attribute[:ip_addrs][0].sub(%r{/\d+$}, '')
  end

  # @param [Netomox::PseudoDSL::PNode] bgp_proc_core_node Core of external-AS
  # @return [Array<Array(Hash, Hash)>] peer_list pair to connected ibgp (full-mesh)
  def bgp_proc_ibgp_router_pairs(bgp_proc_core_node)
    @peer_list.map { |peer_item| peer_item[:bgp_proc] }
              .append({ node_name: bgp_proc_core_node.name, node: bgp_proc_core_node })
              .concat(find_all_bgp_proc_ebgp_candidate_routers.map { |node| { node_name: node.name, node: node } })
              .combination(2)
              .to_a
  end

  # @return [void]
  def make_bgp_proc_topology!
    # add core (aggregation) router
    # NOTE: assign 1st router-id for core router
    bgp_proc_core_node = add_bgp_proc_core_router
    # add edge-router (ebgp speaker and inter-AS links)
    @peer_list.each { |peer_item| add_bgp_proc_ebgp_router(peer_item) }
    # add edge-candidate-router (NOT ebgp yet, but will be ebgp)
    find_all_layer3_ebgp_candidate_routers.each do |router|
      add_bgp_proc_ebgp_candidate_router(router)
    end

    # iBGP mesh
    # router [] -- [tp1] Seg_x.x.x.x [tp2] -- [] router
    bgp_proc_ibgp_router_pairs(bgp_proc_core_node).each do |peer_item_bgp_proc_pair|
      add_bgp_proc_ibgp_links(peer_item_bgp_proc_pair)
    end
  end
end
