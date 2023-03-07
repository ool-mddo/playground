# frozen_string_literal: true

require_relative 'lib/scenario_base'
require_relative 'lib/nw_subsets/network_sets_diff'
require_relative 'lib/reach_test/reach_tester'
require_relative 'lib/reach_test/reach_result_converter'

module LinkdownSimulation
  # topology data operator

  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength

  # Linkdown simulation commands
  class Simulator < ScenarioBase
    desc 'generate_topology [options]', 'Generate topology from config'
    method_option :model_info, aliases: :m, type: :string, default: 'model_info.json', desc: 'Model info (json)'
    method_option :network, aliases: :n, type: :string, required: true, desc: 'Network name'
    method_option :snapshot, aliases: :s, type: :string, desc: 'Snapshot name'
    method_option :phy_ss_only, aliases: :p, type: :boolean, desc: 'Physical snapshot only'
    method_option :format, aliases: :f, default: 'json', type: :string, enum: %w[yaml json], desc: 'Output format'
    method_option :log_level, type: :string, enum: %w[fatal error warn debug info], default: 'info', desc: 'Log level'
    # @return [void]
    def generate_topology
      change_log_level(options[:log_level]) if options.key?(:log_level)

      # check
      @logger.info "option: #{options}"
      @logger.info "model_info: #{options[:model_info]}"

      # option
      api_opts = { model_info: read_json_file(options[:model_info]) }
      if options.key?(:network)
        api_opts[:network] = options[:network]
        api_opts[:snapshot] = options[:snapshot] if options.key?(:snapshot)
      end
      api_opts[:phy_ss_only] = options[:phy_ss_only] if options.key?(:phy_ss_only)
      # send request
      url = '/model-conductor/generate-topology'
      response = @rest_api.post(url, api_opts)
      print_data(parse_json_str(response.body))
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

    # rubocop:disable Metrics/AbcSize

    desc 'compare_subsets [options]', 'Compare topology data before linkdown'
    method_option :min_score, aliases: :m, default: 0, type: :numeric, desc: 'Minimum score to print'
    method_option :format, aliases: :f, default: 'json', type: :string, enum: %w[yaml json], desc: 'Output format'
    method_option :network, aliases: :n, type: :string, required: true, desc: 'Network name'
    method_option :snapshot, aliases: :s, type: :string, required: true, desc: 'Source (physical) snapshot name'
    # @return [void]
    def compare_subsets
      network = options[:network].intern # read json with symbolize_names: true
      snapshot = options[:snapshot] # source (physical) snapshot

      snapshot_patterns = @rest_api.fetch_snapshot_patterns(network, snapshot)
      network_sets_diffs = snapshot_patterns.map do |snapshot_pattern|
        source_snapshot = snapshot_pattern[:source_snapshot_name]
        target_snapshot = snapshot_pattern[:target_snapshot_name]
        NetworkSetsDiff.new(network, source_snapshot, target_snapshot)
      end
      data = network_sets_diffs.map(&:to_data).reject { |d| d[:score] < options[:min_score] }
      print_data(data)
    end
    # rubocop:enable Metrics/AbcSize

    desc 'extract_subsets [options]', 'Extract subsets for each layer in the topology'
    method_option :network, aliases: :n, type: :string, required: true, desc: 'Network name'
    method_option :snapshot, aliases: :s, type: :string, required: true, desc: 'Snapshot name'
    method_option :format, aliases: :f, default: 'json', type: :string, enum: %w[yaml json], desc: 'Output format'
    # @return [void]
    def extract_subsets
      topology_data = @rest_api.fetch_topology_data(options[:network], options[:snapshot])
      nws = Netomox::Topology::DisconnectedVerifiableNetworks.new(topology_data)
      print_data(nws.find_all_network_sets.to_array)
    end

    # rubocop:disable Metrics/MethodLength, Metrics/AbcSize

    desc 'test_reachability PATTERN_FILE', 'Test L3 reachability with pattern file'
    method_option :network, aliases: :n, required: true, type: :string, desc: 'network name in batfish'
    method_option :snapshot_re, aliases: :s, type: :string, default: '.*', desc: 'snapshot name (regexp)'
    method_option :format, aliases: :f, default: 'json', type: :string, enum: %w[yaml json csv],
                           desc: 'Output format (to stdout, ignored with --run_test)'
    method_option :test_pattern, aliases: :t, type: :string, default: 'traceroute_patterns.yaml',
                                 desc: 'test pattern file'
    method_option :run_test, aliases: :r, type: :boolean, default: false, desc: 'Save result to files and run test'
    method_option :log_level, type: :string, enum: %w[fatal error warn debug info], default: 'info', desc: 'Log level'
    # @return [void]
    def test_reachability
      change_log_level(options[:log_level]) if options.key?(:log_level)

      tester = ReachTester.new(options[:test_pattern])
      reach_results = tester.exec_all_traceroute_tests(options[:network], options[:snapshot_re])
      converter = ReachResultConverter.new(reach_results)
      reach_results_summary = converter.summary
      # for debug: without -r option, print data and exit
      unless options[:run_test]
        options[:format] == 'csv' ? print_csv(converter.full_table) : print_data(reach_results_summary)
        exit 0
      end

      file_base = options[:network]
      # save test result (detail/summary)
      save_json_file(reach_results, "#{file_base}.test_detail.json")
      save_json_file(reach_results_summary, "#{file_base}.test_summary.json")
      save_csv_file(converter.full_table, "#{file_base}.test_summary.csv")
      # test_traceroute_result.rb reads fixed file name
      save_json_file(reach_results_summary, '.test_detail.json')
      exec("bundle exec ruby #{__dir__}/lib/reach_test/test_traceroute_result.rb -v silent")
    end
    # rubocop:enable Metrics/MethodLength, Metrics/AbcSize
  end
end

# start CLI tool
LinkdownSimulation::Simulator.start(ARGV)
