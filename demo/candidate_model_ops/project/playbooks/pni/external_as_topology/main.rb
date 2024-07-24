# frozen_string_literal: true

# NOTE: this script must be executed just after step1-1

require 'json'
require 'optparse'
require 'pathname'

require_relative 'bgp_as_data_builder'

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
    options[:flow_data_file] = Pathname(file)
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
  unless options[:param_file].exist?
    warn "Error: Parameter file '#{options[:param_file]}' does not exist."
    exit 1
  end
  unless options[:flow_data_file].exist?
    warn "Error: Flow data file '#{options[:flow_data_file]}' does not exist."
    exit 1
  end
rescue OptionParser::InvalidOption, OptionParser::MissingArgument => e
  warn e.message
  warn opt_parser
  exit 1
end

# main
ext_as_topology_builder = BgpASDataBuilder.new(
  options[:param_file], options[:flow_data_file], options[:api_proxy], options[:network_name]
)
puts JSON.pretty_generate(ext_as_topology_builder.build_topology)
