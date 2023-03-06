# frozen_string_literal: true

require_relative 'scenario_base'

module LinkdownSimulation
  # generate topology
  class TopologyGenerator < ScenarioBase
    private

    # @param [Hash] snapshot_data Snapshot metadata (model_info or snapshot_pattern elements)
    # @return [Boolean] True if the snapshot is logical one
    def logical_snapshot?(snapshot_data)
      snapshot_data.key?(:lost_edges)
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
      @logger.info "[#{network}/#{snapshot}] Generate logical snapshot"
      # TODO: if physical_ss_only=True, removed in configs/network/snapshot/snapshot_info.json
      url = "/configs/#{network}/#{snapshot}/snapshot_patterns"
      # response: snapshot_patterns
      response = @rest_api.post(url)

      snapshot_patterns = parse_json_str(response.body)
      # when a target snapshot specified
      snapshot_patterns.filter! { |sp| sp[:target_snapshot_name] == options[:snapshot] } if options.key?(:snapshot)
      snapshot_patterns
    end

    # rubocop:disable Metrics/MethodLength, Metrics/AbcSize

    # @param [String] model_info_file Model info file (json, default: ./model_info.json)
    # @return [Array<Hash>] List of model info
    def read_model_info_list(model_info_file)
      model_info_list = read_json_file(model_info_file)
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
      @logger.info 'Generate logical snapshots: link-down patterns'
      snapshot_dict = {}

      # model_info: physical snapshot info...origination points
      # snapshot_patterns: logical snapshot info
      read_model_info_list(model_info_file).each do |model_info|
        network = model_info[:network]
        snapshot = model_info[:snapshot]
        @logger.debug "Target: #{network}/#{snapshot}"

        # if -s (--snapshot) have logical snapshot name,
        # then snapshot_dict must has physical snapshot that correspond the logical one
        next if options.key?(:snapshot) && !options[:snapshot].start_with?(snapshot)

        @logger.debug "Add physical snapshot info of #{snapshot} to #{network}"
        snapshot_dict[network] = { physical: [], logical: [] } unless snapshot_dict.keys.include?(network)
        # set physical snapshot info of the network
        snapshot_dict[network][:physical].push(model_info)

        next if options.key?(:phy_ss_only) && options[:phy_ss_only]

        @logger.debug "Add logical snapshot info of #{snapshot} to #{network}"
        snapshot_patterns = generate_snapshot_patterns(network, snapshot)
        # set logical snapshot info of the network
        snapshot_dict[network][:logical] = snapshot_patterns
      end

      @logger.debug "snapshot_dict: #{snapshot_dict}"
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

      @logger.info "[#{target_key}] Query configurations each snapshot and save it to file"
      url = "/queries/#{network}/#{snapshot}"
      @rest_api.post(url)

      @logger.info "[#{target_key}] Generate topology file from query results"
      write_url = "/topologies/#{network}/#{snapshot}"
      @rest_api.post(write_url)

      return unless logical_snapshot?(snapshot_data)

      @logger.info "[#{target_key}] Generate diff data and write back"
      src_snapshot = snapshot_data[:orig_snapshot_name]
      diff_url = "/topologies/#{network}/snapshot_diff/#{src_snapshot}/#{snapshot}"
      diff_response = @rest_api.fetch(diff_url)
      diff_topology_data = parse_json_str(diff_response.body)
      @rest_api.post(write_url, { topology_data: diff_topology_data[:topology_data] })
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
      @logger.info 'Push (register) netoviz index'
      @logger.debug "netoviz_index_data: #{netoviz_index_data}"
      url = '/topologies/index'
      @rest_api.post(url, { index_data: netoviz_index_data })
    end
  end
end
