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

    desc 'compare_subsets [options] BEFORE_TOPOLOGY AFTER_TOPOLOGY', 'Compare topology data before linkdown'
    method_option :min_score, aliases: :m, default: 0, type: :numeric, desc: 'Minimum score to print'
    method_option :format, aliases: :f, default: 'yaml', type: :string, enum: %w[yaml json], desc: 'Output format'
    # @param [String] orig_file Original topology file path
    # @param [Array<String>] target_files Target topology file path
    # @return [void]
    def compare_subsets(orig_file, *target_files)
      network_sets_diffs = target_files.sort.map do |target_file|
        NetworkSetsDiff.new(orig_file, target_file)
      end
      data = network_sets_diffs.map(&:to_data).reject { |d| d[:score] < options[:min_score] }
      print_data(data)
    end

    desc 'get_subsets [options] TOPOLOGY', 'Get subsets for each network in the topology'
    method_option :format, aliases: :f, default: 'yaml', type: :string, enum: %w[yaml json], desc: 'Output format'
    # @param [String] file Topology file path
    # @return [void]
    def get_subsets(file)
      nws = TopologyGenerator.read_topology_data(file)
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
