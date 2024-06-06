# frozen_string_literal: true

require 'csv'
require 'json'
require 'net/http'
require 'netomox'
require 'optparse'
require 'pathname'
require 'yaml'
require_relative 'layer3'

# @param [String] api_proxy
# @param [String] network_name
# @return [Hash] Internal-AS topology data (rfc8345)
def fetch_int_as_topology(api_proxy, network_name)
  url = URI("http://#{api_proxy}/topologies/#{network_name}/original_asis/topology")
  response = Net::HTTP.get_response(url)
  response.is_a?(Net::HTTPSuccess) ? JSON.parse(response.body) : { :error => response.message }
end

# @param [Netomox::Topology::Networks] int_as_topology Topology object of internal-AS
# @param [Integer] remote_asn Remote ASN
# @return [Array<Hash>] peer list
def find_all_peers(int_as_topology, remote_asn)
  peer_list = []
  bgp_proc_nw = int_as_topology.find_network('bgp_proc')
  bgp_proc_nw.nodes.each do |bgp_proc_node|
    bgp_proc_node.termination_points.each do |bgp_proc_tp|
      bgp_proc_attr = bgp_proc_tp.attribute
      next unless bgp_proc_attr.remote_as == remote_asn

      layer3_info = bgp_proc_tp.supports.find { |s| s.ref_network == 'layer3' }
      peer_item = {
        bgp_proc: {
          node_name: bgp_proc_node.name,
          tp_name: bgp_proc_tp.name,
          local_as: bgp_proc_attr.local_as,
          local_ip: bgp_proc_attr.local_ip,
          remote_as: bgp_proc_attr.remote_as,
          remote_ip: bgp_proc_attr.remote_ip
        },
        layer3: {
          node_name: layer3_info.ref_node,
          tp_name: layer3_info.ref_tp
        }
      }
      peer_list.push(peer_item)
    end
  end
  peer_list
end

# @param [String] column Column name
# @param [CSV::Table] flow_data
# @return [Array<String>] items in specified column
def column_items_from_flows(column, flow_data)
  flow_data.map { |row| row.to_h[column] }.uniq
end

# @param [Hash] params Parameters
# @param [] flow_data Flow data
# @return [Hash] External-AS topology data (rfc8345)
def generate_ext_as_topology(params, flow_data)
  int_as_topology_data = fetch_int_as_topology(params[:api_proxy], params[:network_name])
  int_as_topology = Netomox::Topology::Networks.new(int_as_topology_data)
  peer_list = find_all_peers(int_as_topology, params['source_as'].to_i)

  ext_as_topology = Netomox::PseudoDSL::PNetworks.new
  make_ext_as_layer3_nw(ext_as_topology, peer_list, column_items_from_flows('source', flow_data))
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
  opts.banner = "Usage: ruby #{$0} [options]"

  # Define the options
  opts.on("-aAPI_PROXY", "--api-proxy API", "API proxy name") do |api|
    options[:api_proxy] = api
  end

  opts.on("-nNETWORK_NAME", "--network NETWORK_NAME", "Network name") do |network|
    options[:network_name] = network
  end

  opts.on("-pFILE", "--param-file FILE", "Parameter file") do |file|
    options[:param_file] = Pathname.new(file)
  end

  opts.on("-fFILE", "--flow-data FILE", "Flow-data file") do |file|
    options[:flow_data_file] = file
  end

  # Display help message
  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end
end

# Parse the command line arguments
begin
  opt_parser.parse!

  # Check if required options are provided
  if options[:network_name].nil?
    puts "Error: Network name is required."
    puts opt_parser
    exit
  end

  # Check if the parameter file exists
  param_file_path = Pathname.new(options[:param_file])
  unless options[:param_file].exist?
    puts "Error: Parameter file '#{param_file_path}' does not exist."
    exit
  end

  # read parameter file
  params = YAML.load_file(options[:param_file])
  # append params
  params[:api_proxy] = options[:api_proxy]
  params[:network_name] = options[:network_name]

  # read flow-data file
  flow_data = csv_data = CSV.read(options[:flow_data_file], headers: true)
rescue OptionParser::InvalidOption, OptionParser::MissingArgument => e
  puts e.message
  puts opt_parser
  exit 1
rescue Psych::SyntaxError => e
  puts "Error: Failed to parse YAML file: #{e.message}"
  exit 1
rescue CSV::MalformedCSVError => e
  puts "Error: Malformed CSV row: #{e.message}"
  exit 1
end

puts JSON.pretty_generate(generate_ext_as_topology(params, flow_data))
