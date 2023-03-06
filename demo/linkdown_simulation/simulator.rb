# frozen_string_literal: true

require_relative 'lib/topology_generator'
require_relative 'lib/nw_subsets/network_sets_diff'
require_relative 'lib/reach_test/reach_tester'
require_relative 'lib/reach_test/reach_result_converter'

module LinkdownSimulation
  # topology data operator
  class Simulator < TopologyGenerator
    desc 'generate_topology [options]', 'Generate topology from config'
    method_option :model_info, aliases: :m, type: :string, default: 'model_info.json', desc: 'Model info (json)'
    method_option :network, aliases: :n, type: :string, required: true, desc: 'Network name'
    method_option :snapshot, aliases: :s, type: :string, desc: 'Snapshot name'
    method_option :phy_ss_only, aliases: :p, type: :boolean, desc: 'Physical snapshot only'
    method_option :debug, type: :boolean, desc: 'Enable debug output'
    def generate_topology
      change_logger_level(:debug) if options.key?(:debug) && options[:debug]
      # check
      LOGGER.info "api host: #{API_HOST}"
      LOGGER.info "option: #{options}"
      LOGGER.info "model_info: #{options[:model_info]}"

      # scenario
      snapshot_dict = generate_snapshot_dict(options[:model_info])
      save_json_file(snapshot_dict, '.snapshot_dict.json')
      netoviz_index_data = convert_query_to_topology(snapshot_dict)
      save_netoviz_index(netoviz_index_data)
    end

    desc 'compare_subsets [options]', 'Compare topology data before linkdown'
    method_option :min_score, aliases: :m, default: 0, type: :numeric, desc: 'Minimum score to print'
    method_option :format, aliases: :f, default: 'yaml', type: :string, enum: %w[yaml json], desc: 'Output format'
    method_option :network, aliases: :n, type: :string, required: true, desc: 'Network name'
    method_option :snapshot, aliases: :s, type: :string, required: true, desc: 'Source (physical) snapshot name'
    method_option :snapshot_dict, type: :string, default: '.snapshot_dict.json', desc: 'Snapshot data'
    # @return [void]
    def compare_subsets
      network = options[:network].intern # read json with symbolize_names: true
      snapshot = options[:snapshot] # source (physical) snapshot

      snapshot_dict = read_json_file(options[:snapshot_dict])
      unless snapshot_dict.key?(network)
        LOGGER.error "Network: #{network} is not found in snapshot_dict"
        exit(1)
      end

      source_model_info = snapshot_dict[network][:physical].find { |mi| mi[:snapshot] == snapshot }
      if source_model_info.nil?
        LOGGER.error "snapshot: #{snapshot} is not found of #{network} in snapshot_dict"
        exit(1)
      end

      snapshot_patterns = snapshot_dict[network][:logical]
      network_sets_diffs = snapshot_patterns.map do |snapshot_pattern|
        source_snapshot = snapshot_pattern[:source_snapshot_name]
        source_topology = get_topology(network, source_snapshot)
        target_snapshot = snapshot_pattern[:target_snapshot_name]
        target_topology = get_topology(network, target_snapshot)
        NetworkSetsDiff.new("#{network}/#{source_snapshot}", source_topology,
                            "#{network}/#{target_snapshot}", target_topology)
      end
      data = network_sets_diffs.map(&:to_data).reject { |d| d[:score] < options[:min_score] }
      print_data(data)
    end

    desc 'extract_subsets [options]', 'Extract subsets for each layer in the topology'
    method_option :network, aliases: :n, type: :string, required: true, desc: 'Network name'
    method_option :snapshot, aliases: :s, type: :string, required: true, desc: 'Snapshot name'
    method_option :format, aliases: :f, default: 'yaml', type: :string, enum: %w[yaml json], desc: 'Output format'
    # @return [void]
    def extract_subsets
      topology_data = get_topology(options[:network], options[:snapshot])
      nws = Netomox::Topology::DisconnectedVerifiableNetworks.new(topology_data)
      print_data(nws.find_all_network_sets.to_array)
    end

    # rubocop:disable Metrics/MethodLength, Metrics/AbcSize

    desc 'test_reachability PATTERN_FILE', 'Test L3 reachability with pattern file'
    method_option :network, aliases: :n, required: true, type: :string, desc: 'network name in batfish'
    method_option :snapshot_re, aliases: :s, type: :string, default: '.*', desc: 'snapshot name (regexp)'
    method_option :format, aliases: :f, default: 'yaml', type: :string, enum: %w[yaml json csv],
                           desc: 'Output format (to stdout, ignored with --run_test)'
    method_option :run_test, aliases: :r, type: :boolean, default: false, desc: 'Save result to files and run test'
    # @param [String] file Test pattern def file (yaml)
    # @return [void]
    def test_reachability(file)
      tester = ReachTester.new(file)
      reach_results = tester.exec_all_traceroute_tests(options[:network], options[:snapshot_re])
      converter = ReachResultConverter.new(reach_results)
      reach_results_summary = converter.summary
      # for debug: without -r option, print data and exit
      unless options[:run_test]
        options[:format] == 'csv' ? print_csv(converter.full_table) : print_data(reach_results_summary)
        exit 0
      end

      file_base = options[:network]
      summary_json_file = "#{file_base}.test_summary.json"
      detail_json_file = "#{file_base}.test_detail.json"
      summary_csv_file = "#{file_base}.test_summary.csv"
      # save test result (detail/summary)
      print_json_data_to_file(reach_results, detail_json_file)
      print_json_data_to_file(reach_results_summary, summary_json_file)
      print_csv_data_to_file(converter.full_table, summary_csv_file)
      # test_traceroute_result.rb reads fixed file name
      print_json_data_to_file(reach_results_summary, '.test_detail.json')
      exec("bundle exec ruby #{__dir__}/lib/reach_test/test_traceroute_result.rb -v silent")
    end
    # rubocop:enable Metrics/MethodLength, Metrics/AbcSize
  end
end

# start CLI tool
LinkdownSimulation::Simulator.start(ARGV)
