# frozen_string_literal: true

require 'json'
require 'netomox'
require 'net/http'
require 'yaml'

require_relative 'bgp_as'
require_relative 'bgp_proc'
require_relative 'layer3'

# @param [String] api_proxy
# @param [String] network_name
# @return [Hash] Internal-AS topology data (rfc8345)
def fetch_int_as_topology(api_proxy, network_name)
  url = URI("http://#{api_proxy}/topologies/#{network_name}/original_asis/topology")
  response = Net::HTTP.get_response(url)
  JSON.parse(response.body) if response.is_a?(Net::HTTPSuccess)
end

# @param [Netomox::Topology::Networks] Internal-AS topology
# @param [String] preferred_node Node name in internal-AS
# @param [String] preferred_tp Term-point (interface) name of preferred_node
# @return [String] ip address (e.g. "192.168.0.1")
def find_preferred_ip_in_int_as(internal_as_nws, preferred_node, preferred_tp)
  target_tp = internal_as_nws.find_tp('layer3', preferred_node, preferred_tp)
  return '__UNKNOWN__' if target_tp.attribute.ip_addrs.length.zero?

  target_tp.attribute.ip_addrs[0].match(/([\d\.]+)(\/\d+)?/)[1]
end

# @param [Netomox::Topology::Networks] external_as_nws External-AS topology
# @param [String] internal_preferred_ip Peer ip address (internal-AS side)
# @param [Integer] ext_asn AS Number (external-AS side)
# @return [Netomox::Topology::TermPoint] preferred term-point (bgp peer tp) at external-AS side
def find_preferred_tp_in_ext_as(external_as_nws, internal_preferred_ip, ext_asn)
  target_nw = external_as_nws.find_network('bgp_proc')
  target_tp = nil
  target_nw.nodes.each do |node|
    target_tp = node.termination_points.find { |tp| tp.attribute.local_as == ext_asn && tp.attribute.remote_ip == internal_preferred_ip }
    break unless target_tp.nil?
  end
  target_tp
end

# @param [Hash] opts Options
# @return [Hash] External-AS topology data (rfc8345)
def generate_ext_as_topology(opts = {})
  nws = Netomox::DSL::Networks.new
  register_bgp_as(nws)
  register_bgp_proc(nws)
  register_layer3(nws)
  nws.topo_data
end

# main

options = {
  api_proxy: ENV['API_PROXY'] || 'localhost:15000',
  network_name: ENV['NETWORK_NAME'] || 'mddo-bgp'
}

opt_parser = OptionParser.new do |opts|
  opts.banner = "Usage: ruby #{$0} [options]"
  opts.on("-aAPI_PROXY", "--api-proxy=API_PROXY", String, "API proxy URL (optional, default from env-var)") do |api_proxy|
    options[:api_proxy] = api_proxy # overwrite if specified
  end
  opts.on("-nNETWORK_NAME", "--network=NETWORK_NAME", String, "Network name (optional, default from env-var)") do |network_name|
    options[:network_name] = network_name # overwrite if specified
  end
  opts.on("-pPARAM_FILE", "--param-file=PARAM_FILE", String, "YAML parameter file") do |param_file|
    options[:param_file] = param_file
  end
  opts.on_tail("-h", "--help", "Show this message") do
    puts opts
    exit
  end
end

opt_parser.parse!

unless options[:param_file]
  warn "Error: YAML parameter file not provided."
  warn opt_parser
  exit 1
end

param_data = YAML.safe_load_file(options[:param_file])
warn "Parameters loaded from #{options[:param_file]}: #{param_data}"

# internal-AS
internal_as_topology = fetch_int_as_topology(options[:api_proxy], options[:network_name])
internal_as_nws = Netomox::Topology::Networks.new(internal_as_topology)
internal_preferred_ip = find_preferred_ip_in_int_as(internal_as_nws, param_data['preferred_node'], param_data['preferred_interface'])

# external-AS
external_as_topology = generate_ext_as_topology
external_as_nws = Netomox::Topology::Networks.new(external_as_topology)
target_tp = find_preferred_tp_in_ext_as(external_as_nws, internal_preferred_ip, param_data['external_asn'])
target_tp.attribute.flags.push('ext-bgp-speaker-preferred') if target_tp

# output
puts JSON.pretty_generate(external_as_nws.to_data)
