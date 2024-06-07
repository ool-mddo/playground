# frozen_string_literal: true

require 'csv'
require 'json'
require 'ipaddr'
require 'net/http'
require 'netomox'
require 'optparse'
require 'pathname'
require 'yaml'

require_relative 'ip_management'
require_relative 'int_as_topology'
require_relative 'layer3'
require_relative 'bgp_proc'
require_relative 'bgp_as'

# @param [String] column Column name
# @param [CSV::Table] flow_data Flow data
# @return [Array<String>] items in specified column
def column_items_from_flows(column, flow_data)
  flow_data.map { |row| row.to_h[column] }.uniq
end

# @param [Hash] params Parameters
# @param [] flow_data Flow data
# @return [Hash] External-AS topology data (rfc8345)
def generate_ext_as_topology(params, flow_data)
  IPManagement.instance.assign_base_prefix(params['subnet'])

  int_as_topology_data = fetch_int_as_topology(params[:api_proxy], params[:network_name])
  int_as_topology = Netomox::Topology::Networks.new(int_as_topology_data)
  src_peer_list = find_all_peers(int_as_topology, params['source_as'].to_i)
  src_flow_list = column_items_from_flows('source', flow_data)

  ext_as_topology = Netomox::PseudoDSL::PNetworks.new
  make_ext_as_layer3_nw(ext_as_topology, src_peer_list, src_flow_list)
  make_ext_as_bgp_proc_nw(ext_as_topology, src_peer_list)
  make_ext_as_bgp_as_nw(ext_as_topology, int_as_topology, src_peer_list)
  ext_as_topology.interpret.topo_data
end

# main

# Hash to store the options
options = {
  api_proxy: ENV['API_PROXY'] || 'localhost:15000',
  network_name: ENV['NETWORK_NAME'] || 'mddo-bgp',
  param_file: Pathname.new(__FILE__).dirname.parent.join('params.yaml'),
  flow_data_file: Pathname.new(__FILE__).dirname.parent.join('flowdata.csv')
}

# Create OptionParser object
opt_parser = OptionParser.new do |opts|
  opts.banner = "Usage: ruby #{$PROGRAM_NAME} [options]"

  # Define the options
  opts.on('-aAPI_PROXY', '--api-proxy API', 'API proxy name') do |api|
    options[:api_proxy] = api
  end

  opts.on('-nNETWORK_NAME', '--network NETWORK_NAME', 'Network name') do |network|
    options[:network_name] = network
  end

  opts.on('-pFILE', '--param-file FILE', 'Parameter file') do |file|
    options[:param_file] = Pathname.new(file)
  end

  opts.on('-fFILE', '--flow-data FILE', 'Flow-data file') do |file|
    options[:flow_data_file] = file
  end

  # Display help message
  opts.on('-h', '--help', 'Prints this help') do
    puts opts
    exit
  end
end

# Parse the command line arguments
begin
  opt_parser.parse!

  # Check if required options are provided
  if options[:network_name].nil?
    warn 'Error: Network name is required.'
    warn opt_parser
    exit
  end

  # Check if the parameter file exists
  param_file_path = Pathname.new(options[:param_file])
  unless options[:param_file].exist?
    warn "Error: Parameter file '#{param_file_path}' does not exist."
    exit
  end

  # read parameter file
  params = YAML.load_file(options[:param_file])
  # append params
  params[:api_proxy] = options[:api_proxy]
  params[:network_name] = options[:network_name]

  # read flow-data file
  flow_data = CSV.read(options[:flow_data_file], headers: true)
rescue OptionParser::InvalidOption, OptionParser::MissingArgument => e
  warn e.message
  warn opt_parser
  exit 1
rescue Psych::SyntaxError => e
  warn "Error: Failed to parse YAML file: #{e.message}"
  exit 1
rescue CSV::MalformedCSVError => e
  warn "Error: Malformed CSV row: #{e.message}"
  exit 1
end

puts JSON.pretty_generate(generate_ext_as_topology(params, flow_data))
