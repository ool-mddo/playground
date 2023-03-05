# frozen_string_literal: true

# Networks  .........................  NetworkSets
#   + Network (layer)  ................. + NetworkSet
#       + Sub-network (sub-graph)  ........  * NetworkSubset

module LinkdownSimulation
  # network sets: network sets
  class NetworkSets
    # @!attribute [r] network\sets
    #   @return [Array<NetworkSet>]
    attr_reader :sets

    # @param [Array<Netomox::Topology::Network>] networks Networks
    def initialize(networks)
      @sets = networks.map(&:find_all_subsets)
    end

    # @param [String] name Network name to find
    # @return [nil, NetworkSet] Found network-set
    def network(name)
      @sets.find { |set| set.network_name == name }
    end

    # @param [NetworkSets] other
    # @return [Hash]
    # @raise [StandardError]
    def diff(other)
      @sets.map(&:network_name).to_h do |nw_name|
        orig_set = network(nw_name)
        target_set = other.network(nw_name)
        raise StandardError, 'network name not found in NetworkSet' if orig_set.nil? || target_set.nil?

        [nw_name.intern, subtract_result(orig_set, target_set)] # [key, value] to hash
      end
    end

    # @return [Array<Hash>]
    def to_array
      @sets.map do |set|
        subsets = set.to_array
        {
          network: set.network_name,
          subsets_count: subsets.length,
          subsets:
        }
      end
    end

    private

    # @param [NetworkSet] orig_set
    # @param [NetworkSet] target_set
    # @return [Hash]
    def subtract_result(orig_set, target_set)
      lost = orig_set.elements_diff(target_set)
      found = target_set.elements_diff(orig_set)
      elements_diff = lost | found
      {
        subsets_diff_count: (orig_set.subsets.length - target_set.subsets.length).abs,
        elements_diff: { lost:, found: },
        elements_diff_count: elements_diff.length,
        flag_diff_count: orig_set.flag_diff(target_set).abs
      }
    end
  end
end
