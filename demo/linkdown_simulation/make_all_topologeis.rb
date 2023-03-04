# frozen_string_literal: true

require 'fileutils'
require 'httpclient'
require 'json'
require 'optparse'
require 'parallel'

# HTTP Client
HTTP_CLIENT = HTTPClient.new
HTTP_CLIENT.receive_timeout = 60 * 60 * 4 # 60sec * 60min * 4h
# REST API proxy
API_HOST = ENV.fetch('MDDO_API_HOST', 'localhost:15000')

# http-client wrapper functions

def error_response?(response)
  # Error when status code is not 2xx
  response.status % 100 == 2
end

# @param [String] api_path PATH of REST API
# @param [Hash] data Data to post
# @return [HTTP::Message,nil] Reply
def mddo_post(api_path, data = {})
  header = { 'Content-Type' => 'application/json' }
  body = JSON.generate(data)
  str_limit = 80
  data_str = data.to_s.length < str_limit ? data.to_s : "#{data.to_s[0, str_limit - 3]}..."
  url = "http://#{API_HOST}/#{api_path}"
  puts "# - POST: #{url}, data=#{data_str}"
  response = HTTP_CLIENT.post(url, body:, header:)
  warn "# [ERROR] #{response.status} < POST #{url}, data=#{data_str}" if error_response?(response)
  response
end

# @param [String] api_path PATH of REST API
# @return [HTTP::Message,nil] Reply
def mddo_get(api_path)
  url = "http://#{API_HOST}/#{api_path}"
  puts "# - GET: #{url}"
  response = HTTP_CLIENT.get(url)
  warn "# [ERROR] #{response.status} < GET #{url}" if error_response?(response)
  response
end

# operations for a single snapshot

# @param [Hash] snapshot_data Snapshot metadata (model_info or snapshot_pattern elements)
# @return [Boolean] True if the snapshot is logical one
def logical_snapshot?(snapshot_data)
  snapshot_data.key?(:lost_edges)
end

# rubocop:disable Metrics/MethodLength

# @param [String] network Network name
# @param [Hash] snapshot_data Snapshot metadata (model_info or snapshot_pattern elements)
# @return [void]
def process_snapshot_data(network, snapshot_data)
  snapshot = snapshot_data[logical_snapshot?(snapshot_data) ? :target_snapshot_name : :snapshot]
  target_key = "#{network}/#{snapshot}"

  puts "# [#{target_key}] Query configurations each snapshot and save it to file"
  url = "/queries/#{network}/#{snapshot}"
  mddo_post(url)

  puts "# [#{target_key}] Generate topology file from query results"
  write_url = "/topologies/#{network}/#{snapshot}"
  mddo_post(write_url)

  return unless logical_snapshot?(snapshot_data)

  puts "# [#{target_key}] Generate diff data and write back"
  src_snapshot = snapshot_data[:orig_snapshot_name]
  diff_url = "/topologies/#{network}/snapshot_diff/#{src_snapshot}/#{snapshot}"
  diff_response = mddo_get(diff_url)
  diff_topology_data = JSON.parse(diff_response.body, { symbolize_names: true })
  mddo_post(write_url, { topology_data: diff_topology_data[:topology_data] })
end
# rubocop:enable Metrics/MethodLength

# @param [String] network Network name
# @param [String] snapshot Snapshot name
# @param [String] label Label string
# @return [Hash] Netoviz index (element)
def netoviz_index_datum(network, snapshot, label)
  # file name is FIXED (topology.json)
  { 'network' => network, 'snapshot' => snapshot, 'file' => 'topology.json', 'label' => label }
end

# option parse

opt = {}
parser = OptionParser.new
parser.on('-n', '--network NETWORK', 'Network name') { |v| opt[:network] = v }
parser.on('-s', '--snapshot SNAPSHOT', 'Snapshot name') { |v| opt[:snapshot] = v }
parser.on('--physical_ss_only', 'Physical snapshot only') { |v| opt[:physical_ss_only] = v }
parser.on('--debug', 'Enable debug output') { |v| opt[:debug] = v }
parser.parse!(ARGV)

# check

puts '# ---'
puts "# api host: #{API_HOST}"
puts "# option  : #{opt}"
puts '# ---'

# scenario

puts '# Generate logical snapshots: link-down patterns'
model_info_list = JSON.parse(File.read('./model_info.json'), { symbolize_names: true })
snapshot_dict = {}
model_info_list.each do |model_info|
  warn "# [DEBUG] model_info: #{model_info}" if opt[:debug]
  if opt.key?(:network) && opt[:network] != model_info[:network]
    warn '# [DEBUG] skip: model_info does not match network option' if opt[:debug]
    next
  end

  # check off "fixed" model for link-down simulation (FORCE physical snapshot ONLY)
  if model_info[:type] == 'fixed' || opt[:physical_ss_only]
    snapshot_dict[model_info[:network]] = { physical: model_info, logical: [] }
    warn '# [DEBUG] skip: network type of the model_info is fixed or enable physical snapshot only' if opt[:debug]
    next
  end

  network = model_info[:network]
  snapshot = model_info[:snapshot]
  puts "# [#{network}/#{snapshot}] Generate logical snapshot"
  # TODO: if physical_ss_only=True, removed in configs/network/snapshot/snapshot_info.json
  url = "/configs/#{network}/#{snapshot}/patterns"
  # response: snapshot-patterns
  response = mddo_post(url)

  # snapshot_dict = {
  #   <network name> => {
  #     physical: (model_info),
  #     logical: [
  #       (snapshot_pattern)
  #     ]
  #   }
  # }
  snapshot_patterns = JSON.parse(response.body, { symbolize_names: true })
  # for debug, for single snapshot
  snapshot_patterns.filter! { |sp| sp[:target_snapshot_name] == opt[:snapshot] } if opt.key?(:snapshot)
  snapshot_dict[model_info[:network]] = {
    physical: model_info,
    logical: snapshot_patterns
  }
end

warn "# [DEBUG] snapshot_dict: #{snapshot_dict}" if opt[:debug]

netoviz_index_data = []
snapshot_dict.each_pair do |network, snapshot_info|
  # physical snapshot
  model_info = snapshot_info[:physical]
  process_snapshot_data(network, model_info)
  datum = netoviz_index_datum(network, model_info[:snapshot], model_info[:label])
  netoviz_index_data.push(datum)

  # logical snapshots (link-down snapshots)
  snapshot_info[:logical].each do |snapshot_pattern|
    process_snapshot_data(network, snapshot_pattern)
    datum = netoviz_index_datum(network, snapshot_pattern[:target_snapshot_name], snapshot_pattern[:description])
    netoviz_index_data.push(datum)
  end
end

puts '# Push (register) netoviz index'
warn "# [DEBUG] netoviz_index_data: #{netoviz_index_data}" if opt[:debug]
url = '/topologies/index'
mddo_post(url, { index_data: netoviz_index_data })
