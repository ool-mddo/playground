# frozen_string_literal: true

require 'forwardable'
require 'json'
require 'netomox'
require_relative './disconnected_verifiable_networks'

# 4fc8345 based topology operations
module LinkdownSimulation
  # @param [String] file_path Topology file path
  # @return [Netomox::Topology::DisconnectedVerifiableNetworks]
  def read_topology_data(file_path)
    raw_topology_data = JSON.parse(File.read(file_path))
    Netomox::Topology::DisconnectedVerifiableNetworks.new(raw_topology_data)
  end
  module_function :read_topology_data

  # handle subtract (diff) information of NetworkSets
  class NetworkSetsDiff
    # @!attribute [r] orig_file
    #   @return [String]
    # @!attribute [r] orig_sets
    #   @return [NetworkSet]
    # @!attribute [r] target_file
    #   @return [String]
    # @!attribute [r] target_sets
    #   @return [NetworkSet]
    # @!attribute [r] compared
    #   @return [Hash]
    attr_reader :orig_file, :orig_sets, :target_file, :target_sets, :compared

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

    # @param [String] orig_file Original topology file path
    # @param [String] target_file Target topology file path
    def initialize(orig_file, target_file)
      @orig_file = orig_file
      @orig_sets = disconnected_check(orig_file)
      @target_file = target_file
      @target_sets = disconnected_check(target_file)
      # Hash, { network_name: { subsets_count_diff: Integer, elements_diff: Array<String> }}
      # @see NetworkSets#-, NetworkSets#subtract_result
      @compared = orig_sets.diff(target_sets)
    end

    # @return [Hash]
    def to_data
      print_datum1 = {
        original_file: @orig_file,
        target_file: @target_file,
        score: calculate_score
      }
      print_datum2 = @compared.each_key.to_h do |nw_name|
        [nw_name, network_datum(nw_name)] # to hash [key, value]
      end
      print_datum1.merge(print_datum2)
    end

    private

    # @param [String] file_path Topology file path
    # @return [NetworkSets] Network sets
    def disconnected_check(file_path)
      nws = TopologyGenerator.read_topology_data(file_path)
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
