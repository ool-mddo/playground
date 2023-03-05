# frozen_string_literal: true

require 'fileutils'
require 'httpclient'
require 'json'
require 'optparse'
require 'thor'

module LinkdownSimulation
  # rubocop:disable Metrics/ClassLength

  # generate topology
  class GenerateTopologyRunner < Thor
    # HTTP Client
    HTTP_CLIENT = HTTPClient.new
    HTTP_CLIENT.receive_timeout = 60 * 60 * 4 # 60sec * 60min * 4h
    # REST API proxy
    API_HOST = ENV.fetch('MDDO_API_HOST', 'localhost:15000')

    desc 'generate_topology [options] model_info', 'Generate topology from config'
    method_option :model_info, aliases: :m, type: :string, default: 'model_info.json', desc: 'Model info (json)'
    method_option :network, aliases: :n, type: :string, desc: 'Network name'
    method_option :snapshot, aliases: :s, type: :string, desc: 'Snapshot name'
    method_option :phy_ss_only, aliases: :p, type: :boolean, desc: 'Physical snapshot only'
    method_option :debug, type: :boolean, desc: 'Enable debug output'
    def generate_topology
      # check
      puts '# ---'
      puts "# api host   : #{API_HOST}"
      puts "# option     : #{options}"
      puts "# model_info : #{options[:model_info]}"
      puts '# ---'

      # scenario
      snapshot_dict = generate_snapshot_dict(options[:model_info])
      netoviz_index_data = convert_query_to_topology(snapshot_dict)
      save_netoviz_index(netoviz_index_data)
    end

    private

    # @param [String] message Print message
    # @return [void]
    def debug_print(message)
      warn "# [DEBUG] #{message}" if options[:debug]
    end

    # @param [HTTP::Message] response HTTP response
    # @return [Boolean]
    def error_response?(response)
      # Error when status code is not 2xx
      response.status % 100 == 2
    end

    # @param [Hash] snapshot_data Snapshot metadata (model_info or snapshot_pattern elements)
    # @return [Boolean] True if the snapshot is logical one
    def logical_snapshot?(snapshot_data)
      snapshot_data.key?(:lost_edges)
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

    # @param [String] network Network name
    # @param [String] snapshot Snapshot name
    # @param [String] label Label string
    # @return [Hash] Netoviz index (element)
    def netoviz_index_datum(network, snapshot, label)
      # file name is FIXED (topology.json)
      { 'network' => network, 'snapshot' => snapshot, 'file' => 'topology.json', 'label' => label }
    end

    def generate_snapshot_patterns(network, snapshot)
      puts "# [#{network}/#{snapshot}] Generate logical snapshot"
      # TODO: if physical_ss_only=True, removed in configs/network/snapshot/snapshot_info.json
      url = "/configs/#{network}/#{snapshot}/snapshot_patterns"
      # response: snapshot_patterns
      response = mddo_post(url)

      snapshot_patterns = JSON.parse(response.body, { symbolize_names: true })
      # when a target snapshot specified
      snapshot_patterns.filter! { |sp| sp[:target_snapshot_name] == options[:snapshot] } if options.key?(:snapshot)
      snapshot_patterns
    end

    # rubocop:disable Metrics/MethodLength, Metrics/AbcSize

    # @param [String] model_info_file Model info file (json, default: ./model_info.json)
    # @return [Array<Hash>] List of model info
    def read_model_info_list(model_info_file)
      model_info_list = JSON.parse(File.read(model_info_file), { symbolize_names: true })
      model_info_list.filter! { |info| info[:network] == options[:network] } if options.key?(:network)
      model_info_list
    end

    # @param [String] model_info_file Model info file (json, default: ./model_info.json)
    # @return [Hash] logical/physical snapshot info
    # snapshot_dict = {
    #   <network name> => {
    #     physical: [ (model_info),... ],
    #     logical: [ (snapshot_pattern),... ]
    #   }
    # }
    def generate_snapshot_dict(model_info_file)
      puts '# Generate logical snapshots: link-down patterns'
      snapshot_dict = {}

      # model_info: physical snapshot info...origination points
      # snapshot_patterns: logical snapshot info
      read_model_info_list(model_info_file).each do |model_info|
        network = model_info[:network]
        snapshot = model_info[:snapshot]
        debug_print "Target: #{network}/#{snapshot}"

        # if -s (--snapshot) have logical snapshot name,
        # then snapshot_dict must has physical snapshot that correspond the logical one
        next if options.key?(:snapshot) && !options[:snapshot].start_with?(snapshot)

        debug_print "Add physical snapshot info of #{snapshot} to #{network}"
        snapshot_dict[network] = { physical: [], logical: [] } unless snapshot_dict.keys.include?(network)
        # set physical snapshot info of the network
        snapshot_dict[network][:physical].push(model_info)

        next if options.key?(:phy_ss_only) && options[:phy_ss_only]

        debug_print "Add logical snapshot info of #{snapshot} to #{network}"
        snapshot_patterns = generate_snapshot_patterns(network, snapshot)
        # set logical snapshot info of the network
        snapshot_dict[network][:logical] = snapshot_patterns
      end

      debug_print "snapshot_dict: #{snapshot_dict}"
      snapshot_dict
    end
    # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

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

    # rubocop:disable Metrics/MethodLength

    # @param [Hash] snapshot_dict Physical and logical snapshot info for each network
    # @return [Array<Hash>] netoviz index data
    def convert_query_to_topology(snapshot_dict)
      netoviz_index_data = []
      snapshot_dict.each_pair do |network, snapshot_info|
        # physical snapshot
        snapshot_info[:physical].each do |model_info|
          process_snapshot_data(network, model_info)
          datum = netoviz_index_datum(network, model_info[:snapshot], model_info[:label])
          netoviz_index_data.push(datum)
        end

        # logical snapshots (link-down snapshots)
        snapshot_info[:logical].each do |snapshot_pattern|
          process_snapshot_data(network, snapshot_pattern)
          datum = netoviz_index_datum(network, snapshot_pattern[:target_snapshot_name], snapshot_pattern[:description])
          netoviz_index_data.push(datum)
        end
      end
      netoviz_index_data
    end
    # rubocop:enable Metrics/MethodLength

    # @param [Array<Hash>] netoviz_index_data Netoviz index data
    # @return [void]
    def save_netoviz_index(netoviz_index_data)
      puts '# Push (register) netoviz index'
      debug_print "netoviz_index_data: #{netoviz_index_data}"
      url = '/topologies/index'
      mddo_post(url, { index_data: netoviz_index_data })
    end
  end
  # rubocop:enable Metrics/ClassLength
end

# start CLI tool
LinkdownSimulation::GenerateTopologyRunner.start(ARGV)
