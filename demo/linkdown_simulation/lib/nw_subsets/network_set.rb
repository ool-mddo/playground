# frozen_string_literal: true

module LinkdownSimulation
  # Network set: network subsets in a network (layer)
  class NetworkSet
    # @!attribute [r] network_name
    #   @return [String]
    # @!attribute [r] subsets
    #   @return [Array<NetworkSubset>]
    attr_reader :network_name, :subsets

    # @param [String] network_name Network name
    def initialize(network_name)
      @network_name = network_name
      @subsets = [] # list of network subset
    end

    # @param [String] element_path Path of node/term-point to search
    # @return [nil, NetworkSubset] Found network subset
    def find_subset_includes(element_path)
      @subsets.find { |ss| ss.elements.include?(element_path) }
    end

    # @return [Array] Array of subset-elements
    def to_array
      @subsets.map(&:to_data)
    end

    # @return [NetworkSet] self
    def reject_empty_set!
      @subsets.reject! { |ss| ss.elements.empty? }
      self
    end

    # @param [NetworkSet] other
    # @return [Array<String>]
    def elements_diff(other)
      # NOTE: For now, the target is a pattern of "link-down".
      #   The original set contains all links, and the target should have fewer components than that.
      #   The result of subtraction does not contains elements which only in the target (increased elements).
      #   e.g. [1,2,3,4,5] - [3,4,5,6,7] # => [1, 2]
      # @see NetworkSets#subtract_result
      union_subset_elements - other.union_subset_elements
    end

    # @param [NetworkSet] other
    # @return [Integer]
    def flag_diff(other)
      union_subset_flags - other.union_subset_flags
    end

    protected

    # @return [Array<String>] Union all subset elements
    def union_subset_elements
      @subsets.inject([]) { |union, subset| union | subset.elements }
    end

    # Make summary count of count,
    # non-zero or True(=1) flags for each subsets in this network
    # @return [Integer]
    def union_subset_flags
      @subsets.inject(0) do |sum, subset|
        sum + subset.flag.values.inject(0) { |sum2, v| sum2 + to_integer(v) }
      end
    end

    private

    # @param [Integer, TrueClass, FalseClass] value A value of flag
    # @return [Integer]
    def to_integer(value)
      return 1 if value.is_a?(TrueClass)
      return value.to_i if value.is_a?(Integer)

      0
    end
  end
end
