# frozen_string_literal: true

require_relative 'reach_pattern_handler'
require_relative 'bf_trace_results'
require_relative 'bf_wrapper_query_base'

module LinkdownSimulation
  # Reachability tester
  class ReachTester < BFWrapperQueryBase
    # @param [String] pattern_file Test pattern file name (json)
    def initialize(pattern_file)
      super()
      reach_ops = ReachPatternHandler.new(pattern_file)
      @patterns = reach_ops.expand_patterns.reject { |pt| pt[:cases].empty? }
    end

    # rubocop:disable Metrics/MethodLength

    # @param [String] network Network name to analyze (in batfish)
    # @param [String] snapshot_re Snapshot name regexp
    # @return [Array<Hash>]
    def exec_all_traceroute_tests(network, snapshot_re)
      snapshots = fetch_snapshots(network, true)
      return [] if snapshots.nil?

      snapshots.grep(Regexp.new(snapshot_re)).map do |snapshot|
        {
          network:,
          snapshot:,
          description: fetch_snapshot_description(network, snapshot),
          patterns: @patterns.map do |pattern|
            {
              pattern: pattern[:pattern],
              cases: pattern[:cases].map { |c| exec_traceroute_test(c, network, snapshot) }
            }
          end
        }
      end
    end
    # rubocop:enable Metrics/MethodLength

    private

    # @param [String] network Network name to analyze (in batfish)
    # @param [String] snapshot Snapshot name in bf_network
    # @return [String] Description of the snapshot
    def fetch_snapshot_description(network, snapshot)
      snapshot_pattern = fetch_snapshot_pattern(network, snapshot)
      return 'Origin snapshot?' if snapshot_pattern.nil?
      # Origin (physical) snapshot: returns all logical snapshot patterns
      return 'Origin snapshot' if snapshot_pattern.is_a?(Array)
      # Logical snapshot: returns single snapshot pattern
      return snapshot_pattern[:description] if snapshot_pattern.key?(:description)

      '(Description not found)'
    end

    # @param [Hash] test_case Test case
    def test_case_to_str(test_case)
      "#{test_case[:src][:node]}[#{test_case[:src][:intf]}] -> #{test_case[:dst][:node]}[#{test_case[:dst][:intf]}]"
    end

    # @param [Hash] test_case Expanded test case
    # @param [String] network Network name to analyze (in batfish)
    # @param [String] snapshot Snapshot name in bf_network
    # @return [Hash]
    def exec_traceroute_test(test_case, network, snapshot)
      warn "- traceroute: #{network}/#{snapshot} #{test_case_to_str(test_case)}"
      src = test_case[:src]
      traceroute_result = fetch_traceroute(network, snapshot, src[:node], src[:intf], test_case[:dst][:intf_ip])
      { case: test_case, traceroute: BFTracerouteResults.new(traceroute_result).to_data }
    end
  end
end
