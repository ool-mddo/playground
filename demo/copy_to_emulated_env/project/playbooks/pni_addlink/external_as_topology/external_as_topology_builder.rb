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
    params = read_params_file(params_file)
    flow_data = read_flow_data_file(flow_data_file)
    int_as_topology_data = fetch_int_as_topology(api_proxy, network_name)

    @int_as_topology = Netomox::Topology::Networks.new(int_as_topology_data)
    @ext_as_topology = Netomox::PseudoDSL::PNetworks.new

    @ipam = IPManagement.instance # singleton
    @ipam.assign_base_prefix(params['subnet'])

    @src_peer_list = find_all_peers(params['source_as'].to_i)
    @src_flow_list = column_items_from_flows('source', flow_data)
  end

  # @return [Hash] External-AS topology data (rfc8345)
  def build_topology
    make_ext_as_layer3_nw
    make_ext_as_bgp_proc_nw
    make_ext_as_bgp_as_nw
    @ext_as_topology.interpret.topo_data
  end

  private

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
