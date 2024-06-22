# frozen_string_literal: true

require 'csv'
require 'ipaddr'
require 'netomox'

require_relative 'int_as_data_builder'
require_relative 'ip_addr_management'
require_relative 'layer3_data_builder_routers'
require_relative 'layer3_data_builder_ibgp_links'
require_relative 'layer3_data_builder_endpoint'

# Layer3 network data builder
class Layer3DataBuilder < IntASDataBuilder
  # @param [Symbol] as_type (enum: [source_as, :dest_as])
  # @param [String] params_file Params file path
  # @param [String] flow_data_file Flow data file path
  # @param [String] api_proxy API proxy (host:port str)
  # @param [String] network_name Network name
  def initialize(as_type, params_file, flow_data_file, api_proxy, network_name)
    super(as_type, params_file, api_proxy, network_name)

    flow_data = read_flow_data_file(flow_data_file)
    @flow_prefixes = column_items_from_flows(flow_data)

    @ipam = IPAddrManagement.instance # singleton
    @ipam.assign_base_prefix(@params['subnet'])

    # target external-AS topology (empty)
    @ext_as_topology = Netomox::PseudoDSL::PNetworks.new

    # layer3 network
    @layer3_nw = @ext_as_topology.network('layer3')
    @layer3_nw.type = Netomox::NWTYPE_MDDO_L3
    @layer3_nw.attribute = { name: 'mddo-layer3-network' }

    make_layer3_topology!
  end

  protected

  # @param [String] suffix Router-name suffix
  # @return [String] Router-name
  def layer3_router_name(suffix)
    "as#{@as_state[:ext_asn]}-#{suffix}"
  end

  # @return [Array<Netomox::PseudoDSL::PNode>] ebgp-candidate-routers
  def find_all_layer3_ebgp_candidate_routers
    @layer3_nw.nodes.find_all do |node|
      node.attribute.key?(:flags) && node.attribute[:flags].include?('ebgp-candidate-router')
    end
  end

  private

  # @param [Netomox::Topology::Node, Netomox::PseudoDSL::PNode] node1
  # @param [Netomox::Topology::TermPoint, Netomox::PseudoDSL::PTermPoint] tp1
  # @param [Netomox::Topology::Node, Netomox::PseudoDSL::PNode] node2
  # @param [Netomox::Topology::TermPoint, Netomox::PseudoDSL::PTermPoint] tp2
  # @return [void]
  def add_layer3_link(node1, tp1, node2, tp2)
    @layer3_nw.link(node1.name, tp1.name, node2.name, tp2.name)
    @layer3_nw.link(node2.name, tp2.name, node1.name, tp1.name)
  end

  # @param [IPAddr] ipaddr
  # @return [String] ip/prefix format tstring (e.g. "a.b.c.d/nn")
  def ipaddr_to_full_str(ipaddr)
    "#{ipaddr}/#{ipaddr.prefix}"
  end

  # @return [void]
  def make_layer3_topology!
    # add core (aggregation) router
    layer3_core_node = add_layer3_core_router
    # add edge-router (ebgp speaker and inter-AS links)
    @peer_list.each_with_index { |peer_item, peer_index| add_layer3_edge_router(peer_item, peer_index) }
    # add edge-candidate-router (NOT ebgp yet, but will be ebgp)
    @params['add_links']&.each { |add_link| add_layer3_ebgp_candidate_router(add_link) }

    # iBGP mesh
    # router [] -- [tp1] Seg_x.x.x.x [tp2] -- [] router
    ibgp_router_pairs(layer3_core_node).each do |peer_item_l3_pair|
      add_layer3_ibgp_links(peer_item_l3_pair)
    end

    # endpoint = iperf node
    # endpoint [] -- [tp1] Seg_y.y.y.y [tp2] -- [] core
    @flow_prefixes.each_with_index do |flow_prefix, flow_index|
      add_layer3_core_to_endpoint_links(layer3_core_node, flow_prefix, flow_index)
    end
  end

  # @param [String] file_path Flow data file path
  # @return [CSV::Table] flow data
  def read_flow_data_file(file_path)
    CSV.read(file_path, headers: true)
  rescue CSV::MalformedCSVError => e
    warn "Error: Malformed CSV row: #{e.message}"
    exit 1
  end

  # @param [CSV::Table] flow_data Flow data
  # @return [Array<String>] items in specified column
  def column_items_from_flows(flow_data)
    column = @as_state[:type] == :source_as ? 'source' : 'dest'
    flow_data.map { |row| row.to_h[column] }.uniq
  end
end
