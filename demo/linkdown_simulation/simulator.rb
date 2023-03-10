# frozen_string_literal: true

require_relative 'lib/scenario_base'

module LinkdownSimulation
  # topology data operator

  # rubocop:disable Metrics/ClassLength, Metrics/AbcSize, Metrics/MethodLength

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

    desc 'generate_topology [options]', 'Generate topology from config'
    method_option :model_info, aliases: :m, type: :string, default: 'model_info.json', desc: 'Model info (json)'
    method_option :network, aliases: :n, type: :string, required: true, desc: 'Network name'
    method_option :snapshot, aliases: :s, type: :string, desc: 'Snapshot name (physical)'
    method_option :phy_ss_only, aliases: :p, type: :boolean, desc: 'Physical snapshot only'
    method_option :format, aliases: :f, default: 'json', type: :string, enum: %w[yaml json], desc: 'Output format'
    method_option :log_level, type: :string, enum: %w[fatal error warn debug info], default: 'info', desc: 'Log level'
    method_option :off_node, type: :string, desc: 'Node name to down'
    method_option :off_intf_re, type: :string, desc: 'Interface name to down (regexp)'
    # @return [void]
    def generate_topology
      change_log_level(options[:log_level]) if options.key?(:log_level)

      # check
      @logger.info "option: #{options}"
      @logger.info "model_info: #{options[:model_info]}"

      # option
      api_opts = { model_info: read_json_file(options[:model_info]) }
      if options.key?(:network)
        api_opts[:model_info].filter! { |model_info| model_info[:network] == options[:network] }
        if options.key?(:snapshot)
          api_opts[:model_info].filter! { |model_info| model_info[:snapshot] == options[:snapshot] }
        end
      end
      api_opts[:phy_ss_only] = options[:phy_ss_only] if options.key?(:phy_ss_only)
      if options.key?(:off_node)
        api_opts[:off_node] = options[:off_node]
        api_opts[:off_intf_re] = options[:off_intf_re] if options.key?(:off_intf_re)
      end

      # send request
      url = '/model-conductor/generate-topology'
      response = @rest_api.post(url, api_opts)
      print_data(parse_json_str(response.body))
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

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

    # rubocop:disable Metrics/MethodLength, Metrics/AbcSize

    desc 'test_reachability PATTERN_FILE', 'Test L3 reachability with pattern file'
    method_option :snapshot_re, aliases: :s, type: :string, default: '.*', desc: 'snapshot name (regexp)'
    method_option :test_pattern, aliases: :t, type: :string, default: 'traceroute_patterns.yaml',
                                 desc: 'test pattern file'
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

      file_base = options[:network]
      # save test result (detail/summary)
      save_json_file(reach_results, "#{file_base}.test_detail.json")
      save_json_file(reach_results_summary, "#{file_base}.test_summary.json")
      save_csv_file(reach_results_summary_table, "#{file_base}.test_summary.csv")
      # test_traceroute_result.rb reads fixed file name
      save_json_file(reach_results_summary, '.test_detail.json')
      exec("bundle exec ruby #{__dir__}/lib/test_traceroute_result.rb -v silent")
    end
    # rubocop:enable Metrics/ClassLength, Metrics/MethodLength, Metrics/AbcSize
  end
end

# start CLI tool
LinkdownSimulation::Simulator.start(ARGV)
