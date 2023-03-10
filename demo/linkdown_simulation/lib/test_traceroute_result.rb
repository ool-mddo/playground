# frozen_string_literal: true

require 'test-unit'
require 'json'

# Test traceroute result (json)
class TestTracerouteResult < Test::Unit::TestCase
  JSON.parse(File.read('.test_detail.json'), { symbolize_names: true }).each do |result|
    # network: str,
    # snapshot: str,
    # description: str,
    # patterns: [pattern]
    sub_test_case "Target: #{result[:network]}/#{result[:snapshot]}: #{result[:description]}" do
      result[:patterns].each do |pattern|
        # pattern: str,
        # cases: [ctest_case]
        pattern[:cases].each do |test_case|
          # case: [src, dst],
          # traceroute: [deposition, hops]
          test "#{test_case[:case][0]} -> #{test_case[:case][1]}" do
            depositions = test_case[:traceroute].map { |t| t[0] }
            assert(depositions.all? do |d|
                     %w[ACCEPTED DISABLED].include?(d)
                   end, 'Traceroute expected to be ACCEPTED or DISABLED')
          end
        end
      end
    end
  end
end
