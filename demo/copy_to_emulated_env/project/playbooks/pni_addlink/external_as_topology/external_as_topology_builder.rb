# frozen_string_literal: true

require 'csv'
require 'netomox'
require 'yaml'

require_relative 'ip_management'
require_relative 'int_as_topology'
require_relative 'layer3'
require_relative 'bgp_proc'
require_relative 'bgp_as'

# External-AS topology builder
class ExternalASTopologyBuilder
  # @param [String] params_file Params file path
  # @param [String] flow_data_file Flow data file path
  # @param [String] api_proxy API proxy URL
  # @param [String] network_name Network name
  def initialize(params_file, flow_data_file, api_proxy, network_name)
    @params = read_params_file(params_file)
    @flow_data = read_flow_data_file(flow_data_file)

    int_as_topology_data = fetch_int_as_topology(api_proxy, network_name)
    @int_as_topology = Netomox::Topology::Networks.new(int_as_topology_data)

    @ipam = IPManagement.instance # singleton
    @ipam.assign_base_prefix(@params['subnet'])
  end

  # @return [Hash] External-AS topology data (rfc8345)
  def build_topology
    src_ext_as_topology = build_ext_as_topology(:source_as)
    dst_ext_as_topology = build_ext_as_topology(:dest_as)

    merge_ext_topologies!([src_ext_as_topology, dst_ext_as_topology])
    @ext_as_topology.interpret.topo_data
  end

  private

  # @param [Array<Netomox::PseudoDSL::PNetworks>] src_ext_as_topologies Src/Dst Ext-AS topologies (layer3/bgp-proc)
  # @return [void]
  def merge_ext_topologies!(src_ext_as_topologies)
    @as_state[:type] = :all_as
    @ext_as_topology = Netomox::PseudoDSL::PNetworks.new

    # merge
    %w[layer3 bgp_proc].each do |layer|
      src_ext_as_topologies.each do |src_ext_as_topology|
        src_network = src_ext_as_topology.network(layer)
        dst_network = @ext_as_topology.network(layer)

        dst_network.type = src_network.type
        dst_network.attribute = src_network.attribute

        dst_network.nodes.append(*src_network.nodes)
        dst_network.links.append(*src_network.links)
      end
    end

    # make bgp_as layer
    make_ext_as_bgp_as_nw!
  end

  # @param [Symbol] as_type (enum: [source_as, :dest_as])
  # @return [Netomox::PseudoDSL::PNetworks] External-AS topology
  def build_ext_as_topology(as_type)
    warn "# Build External AS topology: #{as_type}"

    # set state
    if as_type == :source_as
      @as_state = { type: :source_as }
      @peer_list = find_all_peers(@params['source_as'].to_i)
      @flow_list = column_items_from_flows('source', @flow_data)
    else
      @as_state = { type: :dest_as }
      @peer_list = find_all_peers(@params['dest_as'].to_i)
      @flow_list = column_items_from_flows('dest', @flow_data)
    end
    @as_state[:int_asn] = @peer_list.map { |item| item[:bgp_proc][:local_as] }.uniq[0]
    @as_state[:ext_asn] = @peer_list.map { |item| item[:bgp_proc][:remote_as] }.uniq[0]

    # build
    @ext_as_topology = Netomox::PseudoDSL::PNetworks.new
    make_ext_as_layer3_nw!
    make_ext_as_bgp_proc_nw!

    @ext_as_topology
  end

  # @param [String] file_path Params file path
  # @return [Hash] params
  def read_params_file(file_path)
    YAML.load_file(file_path)
  rescue Psych::SyntaxError => e
    warn "Error: Failed to parse YAML file: #{e.message}"
    exit 1
  end

  # @param [String] file_path Flow data file path
  # @return [CSV::Table] flow data
  def read_flow_data_file(file_path)
    CSV.read(file_path, headers: true)
  rescue CSV::MalformedCSVError => e
    warn "Error: Malformed CSV row: #{e.message}"
    exit 1
  end

  # @param [String] column Column name
  # @param [CSV::Table] flow_data Flow data
  # @return [Array<String>] items in specified column
  def column_items_from_flows(column, flow_data)
    flow_data.map { |row| row.to_h[column] }.uniq
  end
end
