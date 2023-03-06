# frozen_string_literal: true

require 'forwardable'
require 'json'
require 'netomox'
require_relative './disconnected_verifiable_networks'

# 4fc8345 based topology operations
module LinkdownSimulation
  # handle subtract (diff) information of NetworkSets
  class NetworkSetsDiff
    # @!attribute [r] orig_ss_path
    #   @return [String]
    # @!attribute [r] orig_sets
    #   @return [NetworkSet]
    # @!attribute [r] target_ss_path
    #   @return [String]
    # @!attribute [r] target_sets
    #   @return [NetworkSet]
    # @!attribute [r] compared
    #   @return [Hash]
    attr_reader :orig_ss_path, :orig_sets, :target_ss_path, :target_sets, :compared

    # Weights to calculate score
    SCORE_WEIGHT = {
      subsets_diff_count: 10,
      flag_diff_count: 5,
      elements_diff_count: 1
    }.freeze

    extend Forwardable
    # @!method []
    #   @see Hash#[]
    def_delegators :@compared, :[]

    # @param [String] network Network name
    # @param [String] orig_snapshot Origin snapshot name
    # @param [String] target_snapshot Target snapshot name
    def initialize(network, orig_snapshot, target_snapshot)
      @orig_ss_path = "#{network}/#{orig_snapshot}"
      @orig_topology = LinkdownSimulation.fetch_topology_data(network, orig_snapshot)
      @orig_sets = disconnected_check(@orig_topology)
      @target_ss_path = "#{network}/#{target_snapshot}"
      @target_topology = LinkdownSimulation.fetch_topology_data(network, target_snapshot)
      @target_sets = disconnected_check(@target_topology)
      # Hash, { network_name: { subsets_count_diff: Integer, elements_diff: Array<String> }}
      # @see NetworkSets#-, NetworkSets#subtract_result
      @compared = orig_sets.diff(target_sets)
    end

    # @return [Hash]
    def to_data
      print_datum1 = {
        original_snapshot: @orig_ss_path,
        target_snapshot: @target_ss_path,
        score: calculate_score
      }
      print_datum2 = @compared.each_key.to_h do |nw_name|
        [nw_name, network_datum(nw_name)] # to hash [key, value]
      end
      print_datum1.merge(print_datum2)
    end

    private

    # @param [Hash] topology_data Topology data
    # @return [NetworkSets] Network sets
    def disconnected_check(topology_data)
      nws = Netomox::Topology::DisconnectedVerifiableNetworks.new(topology_data)
      nws.find_all_network_sets
    end

    # @return [Integer] total score
    def calculate_score
      @compared.values.inject(0) do |sum1, nw_result|
        sum1 + nw_result.keys.filter { |key| key.to_s =~ /_diff_count$/ }.inject(0) do |sum2, key|
          sum2 + (nw_result[key] * SCORE_WEIGHT[key])
        end
      end
    end

    # @param [String] nw_name Network name
    # @return [Hash]
    def network_datum(nw_name)
      {
        subsets_diff_count: @compared[nw_name][:subsets_diff_count],
        elements_diff_count: @compared[nw_name][:elements_diff_count],
        flag_diff_count: @compared[nw_name][:flag_diff_count],
        elements_diff: @compared[nw_name][:elements_diff]
      }
    end
  end
end
