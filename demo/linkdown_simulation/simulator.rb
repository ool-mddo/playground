#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'lib/scenario_base'

module LinkdownSimulation
  # rubocop:disable Metrics/ClassLength

  # Linkdown simulation commands
  class Simulator < ScenarioBase
    desc 'change_branch [options]', 'Change branch of configs/network repository'
    method_option :network, aliases: :n, type: :string, required: true, desc: 'Network name'
    method_option :branch, aliases: :b, type: :string, required: true, desc: 'Branch name'
    def change_branch
      api_opts = { name: options[:branch] }
      url = "/configs/#{options[:network]}/branch"
      response = @rest_api.post(url, api_opts)
      print_data(parse_json_str(response.body))
    end

    desc 'fetch_branch [options]', 'Print current branch of configs/network repository'
    method_option :network, aliases: :n, type: :string, required: true, desc: 'Network name'
    def fetch_branch
      url = "/configs/#{options[:network]}/branch"
      response = @rest_api.fetch(url)
      print_data(parse_json_str(response.body))
    end

    desc 'load_snapshot [options]', 'Load configs into batfish as a snapshot'
    method_option :network, aliases: :n, type: :string, required: true, desc: 'Network name'
    method_option :snapshot, aliases: :s, type: :string, required: true, desc: 'Snapshot name'
    def load_snapshot
      url = "/batfish/#{options[:network]}/#{options[:snapshot]}/register"
      response = @rest_api.post(url)
      print_data(parse_json_str(response.body))
    end

    desc 'fetch_snapshots [options]', 'Print snapshots in network on batfish'
    method_option :network, aliases: :n, type: :string, required: true, desc: 'Network name'
    def fetch_snapshots
      url = "/batfish/#{options[:network]}/snapshots"
      response = @rest_api.fetch(url)
      print_data(parse_json_str(response.body))
    end

    # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
    desc 'generate_topology [options]', 'Generate topology from config'
    method_option :model_info, aliases: :m, type: :string, default: 'model_info.json', desc: 'Model info (json)'
    method_option :network, aliases: :n, type: :string, required: true, desc: 'Network name'
    method_option :snapshot, aliases: :s, type: :string, desc: 'Snapshot name (physical)'
    method_option :phy_ss_only, aliases: :p, type: :boolean, desc: 'Physical snapshot only'
    method_option :format, aliases: :f, default: 'json', type: :string, enum: %w[yaml json], desc: 'Output format'
    method_option :log_level, type: :string, enum: %w[fatal error warn debug info], default: 'info', desc: 'Log level'
    method_option :off_node, type: :string, desc: 'Node name to down'
    method_option :off_intf_re, type: :string, desc: 'Interface name to down (regexp)'
    method_option :use_parallel, type: :boolean, desc: 'Use parallel'
    # @return [void]
    def generate_topology
      change_log_level(options[:log_level]) if options.key?(:log_level)

      # check
      @logger.info "option: #{options}"
      @logger.info "model_info: #{options[:model_info]}"

      # target filtering
      model_info_list = read_json_file(options[:model_info])
      if options.key?(:network)
        model_info_list.filter! { |model_info| model_info[:network] == options[:network] }
        model_info_list.filter! { |model_info| model_info[:snapshot] == options[:snapshot] } if options.key?(:snapshot)
      end

      # initialize (cleaning)
      clean_all_data(model_info_list)

      # option
      opt_data = opts_of_generate_topology
      # send request
      snapshot_dict_list = []
      model_info_list.each do |model_info|
        url = "/model-conductor/topology/#{model_info[:network]}/#{model_info[:snapshot]}"
        opt_data[:label] = model_info[:label]
        response = @rest_api.post(url, opt_data)
        snapshot_dict_list.push(parse_json_str(response.body)[:snapshot_dict])
      end

      # merge snapshot_dict
      snapshot_dict = merge_snapshot_dict_list(snapshot_dict_list)
      print_data(snapshot_dict)

      # save netoviz index
      url = '/topologies/index'
      @rest_api.post(url, { index_data: snapshot_dict_to_index(snapshot_dict) })
    end
    # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

    desc 'compare_subsets [options]', 'Compare topology data before linkdown'
    method_option :min_score, aliases: :m, default: 0, type: :numeric, desc: 'Minimum score to print'
    method_option :format, aliases: :f, default: 'json', type: :string, enum: %w[yaml json], desc: 'Output format'
    method_option :network, aliases: :n, type: :string, required: true, desc: 'Network name'
    method_option :snapshot, aliases: :s, type: :string, required: true, desc: 'Source (physical) snapshot name'
    # @return [void]
    def compare_subsets
      url = "/model-conductor/subsets/#{options[:network]}/#{options[:snapshot]}/compare"
      response = @rest_api.fetch(url, { min_score: options[:min_score] })
      compare_data = parse_json_str(response.body)[:network_sets_diffs]
      print_data(compare_data)
    end

    desc 'extract_subsets [options]', 'Extract subsets for each layer in the topology'
    method_option :network, aliases: :n, type: :string, required: true, desc: 'Network name'
    method_option :snapshot, aliases: :s, type: :string, required: true, desc: 'Snapshot name'
    method_option :format, aliases: :f, default: 'json', type: :string, enum: %w[yaml json], desc: 'Output format'
    # @return [void]
    def fetch_subsets
      url = "/model-conductor/subsets/#{options[:network]}/#{options[:snapshot]}"
      response = @rest_api.fetch(url)
      subsets = parse_json_str(response.body)[:subsets]
      print_data(subsets)
    end

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    desc 'test_reachability PATTERN_FILE', 'Test L3 reachability with pattern file'
    method_option :snapshot_re, aliases: :s, type: :string, default: '.*', desc: 'snapshot name (regexp)'
    method_option :test_pattern, aliases: :t, type: :string, require: true, desc: 'test pattern file'
    method_option :run_test, aliases: :r, type: :boolean, default: false, desc: 'Save result to files and run test'
    method_option :format, aliases: :f, default: 'json', type: :string, enum: %w[yaml json csv],
                           desc: 'Output format (to stdout, ignored with --run_test)'
    method_option :log_level, type: :string, enum: %w[fatal error warn debug info], default: 'info', desc: 'Log level'
    # @return [void]
    def test_reachability
      change_log_level(options[:log_level]) if options.key?(:log_level)

      url = '/model-conductor/reach_test'
      api_opts = { snapshot_re: options[:snapshot_re], test_pattern: read_yaml_file(options[:test_pattern]) }
      response = @rest_api.post(url, api_opts)
      response_data = parse_json_str(response.body)
      reach_results = response_data[:reach_results]
      reach_results_summary = response_data[:reach_results_summary]
      reach_results_summary_table = response_data[:reach_results_summary_table]

      # for debug: without -r option, print data and exit
      unless options[:run_test]
        options[:format] == 'csv' ? print_csv(reach_results_summary_table) : print_data(reach_results_summary)
        exit 0
      end

      file_base = reach_results[0][:network] || 'unknown-network'
      # save test result (detail/summary)
      save_json_file(reach_results, "#{file_base}.test_detail.json")
      save_json_file(reach_results_summary, "#{file_base}.test_summary.json")
      save_csv_file(reach_results_summary_table, "#{file_base}.test_summary.csv")
      # test_traceroute_result.rb reads fixed file name
      save_json_file(reach_results_summary, '.test_detail.json')
      exec("bundle exec ruby #{__dir__}/lib/test_traceroute_result.rb -v silent")
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

    private

    # @param [Array<Hash>] model_info_list List of model-info (target physical snapshot)
    # @return [void]
    def clean_all_data(model_info_list)
      networks = model_info_list.map { |model_info| model_info[:network] }
      networks.uniq.each do |network|
        @rest_api.delete("/queries/#{network}")
        @rest_api.delete("/topologies/#{network}")
      end
    end

    # rubocop:disable Metrics/AbcSize

    # @return [Hash] post request options (/model-conductor/generate-topology)
    def opts_of_generate_topology
      # NOTICE: options is made by thor (CLI options)
      opt_data = {}
      if options.key?(:off_node)
        opt_data[:off_node] = options[:off_node]
        opt_data[:off_intf_re] = options[:off_intf_re] if options.key?(:off_intf_re)
      end
      opt_data[:phy_ss_only] = options[:phy_ss_only] if options.key?(:phy_ss_only)
      opt_data[:use_parallel] = options[:use_parallel] if options.key?(:use_parallel)
      opt_data
    end
    # rubocop:enable Metrics/AbcSize

    # @param [Array<Hash>] snapshot_dict_list List of a snapshot_dict (for single snapshot)
    # @return [Hash] snapshot_dict (merged for all network)
    #
    # input: several snapshot dict for a physical snapshot
    # snapshot_dict_list = [
    #   { network1 => [<physical/logical pair of physical-ss1>] },
    #   { network1 => [<physical/logical pair of physical-ss2>] },
    #   ...
    # ]
    # output: merged snapshot_dict
    # snapshot_dict = {
    #   network1 => [
    #     <physical/logical pair of physical-ss1>,
    #     <physical/logical pair of physical-ss2>,
    #     ...
    #   ]
    # }
    def merge_snapshot_dict_list(snapshot_dict_list)
      merged_snapshot_dict = {}
      snapshot_dict_list.each do |snapshot_dict|
        snapshot_dict.each_key do |network|
          merged_snapshot_dict[network] = [] unless merged_snapshot_dict.key?(network)
          merged_snapshot_dict[network].concat(snapshot_dict[network])
        end
      end
      merged_snapshot_dict
    end

    # @param [Hash] snapshot_dict snapshot_dict
    # @return [Array<Hash>] Index data for netoviz
    def snapshot_dict_to_index(snapshot_dict)
      netoviz_index_data = snapshot_dict.keys.map do |network|
        snapshot_dict[network].map do |snapshot_pair|
          # for physical snapshot
          snapshot_pair[:physical][:file] = 'topology.json'
          # for logical snapshot
          logical_snapshot_index_list = snapshot_pair[:logical].map do |sp|
            { network:, snapshot: sp[:target_snapshot_name], label: sp[:description], file: 'topology.json' }
          end
          [snapshot_pair[:physical], logical_snapshot_index_list]
        end
      end
      netoviz_index_data.flatten
    end
  end
  # rubocop:enable Metrics/ClassLength
end

# start CLI tool
LinkdownSimulation::Simulator.start(ARGV)
