# frozen_string_literal: true

module LinkdownSimulation
  # convert reachability test results
  class ReachResultConverter
    def initialize(traceroute_results)
      @traceroute_results = traceroute_results
    end

    # rubocop:disable Metrics/MethodLength

    # @return [Array<Hash>]
    def summary
      @traceroute_results.map do |traceroute_result|
        {
          network: traceroute_result[:network],
          snapshot: traceroute_result[:snapshot],
          description: traceroute_result[:description],
          patterns: traceroute_result[:patterns].map do |pattern|
            {
              pattern: pattern_str(pattern[:pattern]),
              cases: summary_cases(pattern[:cases])
            }
          end
        }
      end
    end
    # rubocop:enable Metrics/MethodLength

    # @return [Array<Array<String>>]
    def full_table
      rows = @traceroute_results.map do |traceroute_result|
        values = traceroute_result.fetch_values(:network, :snapshot, :description)
        traceroute_result[:patterns].map do |pattern|
          summary_cases_as_table(pattern[:cases]).map do |sr|
            values + [pattern_str(pattern[:pattern])] + sr
          end
        end
      end
      header = [%w[Network Snapshot Description Pattern Source Destination Deposition Hops]]
      header.concat(rows.flatten(2))
    end

    private

    # @param [Array] test_cases Test cases
    # @return [Array<Hash>]
    def summary_cases(test_cases)
      test_cases.map do |test_case|
        src = case_str(test_case[:case][:src])
        dst = case_str(test_case[:case][:dst])
        {
          case: [src, dst],
          traceroute: summary_traceroute_results(test_case[:traceroute])
        }
      end
    end

    # @param [Array<String>] pattern Test pattern (src group, dst group)
    # @return [String]
    def pattern_str(pattern)
      "#{pattern[0]}->#{pattern[1]}"
    end

    # @param [Array] test_cases Test cases
    # @return [Array<Array<String>>]
    def summary_cases_as_table(test_cases)
      test_cases.map { |test_case| cases_to_array(test_case) }
    end

    # @param [Hash] target Source or Destination of test case
    # @return [String]
    def case_str(target)
      "#{target[:node]}[#{target[:intf]}](#{target[:intf_ip]})"
    end

    # @param [Hash] test_case Test case data
    # @return [Array<String>]
    def cases_to_array(test_case)
      [
        case_str(test_case[:case][:src]),
        case_str(test_case[:case][:dst]),
        summary_traceroute_results(test_case[:traceroute])
      ].flatten
    end

    # @param [Array<Hash>] results Traceroute results of traceroute data
    # @return [Array<String>]
    def summary_traceroute_results(results)
      results.each.map do |result|
        result[:traces].map { |trace| [trace[:disposition], trace[:hops].join('->')] }
                       .flatten
      end
    end
  end
end
