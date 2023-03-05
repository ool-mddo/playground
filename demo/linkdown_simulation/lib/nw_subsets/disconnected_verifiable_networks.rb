# frozen_string_literal: true

require 'netomox'
require 'forwardable'
require_relative './network_sets'
require_relative './network_set'
require_relative './network_subsets'

module Netomox
  module Topology
    # Networks with DisconnectedVerifiableNetwork
    class DisconnectedVerifiableNetworks < Networks
      # @return [TopologyOperator::NetworkSets] Found network sets
      def find_all_network_sets
        TopologyOperator::NetworkSets.new(@networks)
      end

      private

      # override
      def create_network(data)
        DisconnectedVerifiableNetwork.new(data)
      end
    end

    # rubocop:disable Metrics/ClassLength

    # Network class to find disconnected sub-graph
    class DisconnectedVerifiableNetwork < Network
      # rubocop:disable Metrics/MethodLength, Metrics/AbcSize

      # Explore connected network elements (subsets)
      #   subset = connected node and term-point paths list (set)
      #   return several subsets when the network have disconnected networks.
      # @return [TopologyOperator::NetworkSet] Network-set (set of network-subsets, in a network(layer))
      def find_all_subsets
        remove_deleted_state_elements!
        network_set = TopologyOperator::NetworkSet.new(@name)

        # select entry point for recursive-network-search
        @nodes.each do |node|
          # if the node doesn't have any interface,
          # it assumes that a standalone node is a single subset.
          if node.termination_points.empty?
            network_set.subsets.push(TopologyOperator::NetworkSubset.new(node.path))
            next
          end

          # if the node has link(s), search connected element recursively
          network_subset = TopologyOperator::NetworkSubset.new
          node.termination_points.each do |tp|
            # explore origin selection:
            # if exists a subset includes the (source) term-point,
            # it should have already been explored.
            next if network_set.find_subset_includes(tp.path)

            find_connected_nodes_recursively(node, tp, network_subset)
          end
          network_set.subsets.push(network_subset.uniq!)
        end
        other_policy_check(network_set.reject_empty_set!)
      end
      # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

      private

      # @note For layer3 network
      # @param [TopologyOperator::NetworkSet] network_set
      # @return [TopologyOperator::NetworkSet]
      def l3_additional_policy_check(network_set)
        network_set.subsets.each do |subset|
          mp_seg_nodes = subset.find_all_multiple_prefix_seg_nodes
          subset.flag[:multiple_prefix_segments] = mp_seg_nodes.length unless mp_seg_nodes.empty?
          dp_seg_nodes = subset.find_all_duplicated_prefix_seg_nodes
          subset.flag[:duplicated_prefix_segments] = dp_seg_nodes.length unless dp_seg_nodes.empty?
        end
        network_set
      end

      # rubocop:disable Metrics/AbcSize, Metrics/MethodLength

      # @note For layer3 or ospf-area network
      # @param [TopologyOperator::NetworkSubset] subset
      # @return [Hash] segment connected term-points in the subnet
      def find_segment_connected_tps(subset)
        seg_table = {}
        subset.elements.each do |target_element|
          target_path_array = target_element.split('__')
          # select node element
          next if target_path_array.length != 2

          src_node = find_node_by_name(target_path_array[1])
          # select segment-type element as source of a link
          next if src_node.nil? || src_node.attribute.node_type != 'segment'

          # all node-type nodes (in layer3 or upper) are connected via a segment-type node
          # either L3 P2P(/30 link)
          src_node.termination_points.each do |src_tp|
            link = find_link_by_source(src_node.name, src_tp.name)
            seg_table[src_node.name] = [] unless seg_table.key?(src_node.name)
            seg_table[src_node.name].push(link.destination.ref_path)
          end
        end
        seg_table
      end
      # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

      # @param [Array<String>] elements Array of term-point paths (value of a seg_table)
      # @return [Array<Netomox::Topology::TermPoint>] Term-point objects
      def seg_table_to_tps(elements)
        elements.map do |path|
          refs = path.split('__')
          node = find_node_by_name(refs[1])
          node.find_tp_by_name(refs[2])
        end
      end

      # @note For ospf-area network
      # @param [TopologyOperator::NetworkSubset] subset
      # @param [String] seg_name
      # @param [Array<Netomox::Topology::TermPoint>] tps
      # @return [void]
      def check_ospf_params_passive(subset, seg_name, tps)
        # passive interface check
        passive_list = tps.map { |tp| tp.attribute.passive }
        if passive_list.count(true) == passive_list.length
          subset.countup_flag(:passive_only_segments)
          Netomox.logger.warn "ospf-area check: passive-only segment: #{seg_name}"
        elsif passive_list.count(false) == 1
          subset.countup_flag(:lonely_ospf_speaker)
          Netomox.logger.error "ospf-area check: found only one ospf-speaker in segment: #{seg_name}"
        end
      end

      # @note For ospf-area network
      # @param [TopologyOperator::NetworkSubset] subset
      # @param [String] seg_name
      # @param [Array<Netomox::Topology::TermPoint>] tps
      # @return [void]
      def check_ospf_params_timer(subset, seg_name, tps)
        # ospf timer check
        timer_list = tps.map { |tp| tp.attribute.timer }
                        .map { |tmr| [tmr.hello_interval, tmr.dead_interval, tmr.retransmission_interval] }
                        .uniq
        return unless timer_list.length > 1

        subset.countup_flag(:segment_has_mixed_timer)
        Netomox.logger.error "ospf-area check: mixed timers #{timer_list} in seg: #{seg_name}"
      end

      # @note For ospf-area network
      # @param [TopologyOperator::NetworkSet] network_set
      # @return [TopologyOperator::NetworkSet]
      def ospf_additional_policy_check(network_set)
        network_set.subsets.each do |subset|
          subset_seg_table = find_segment_connected_tps(subset)
          subset_seg_table.each_key do |seg|
            tps = seg_table_to_tps(subset_seg_table[seg])
            check_ospf_params_passive(subset, seg, tps)
            check_ospf_params_timer(subset, seg, tps)
          end
        end
        network_set
      end

      # @note For layer3 or ospf-area network
      # @param [TopologyOperator::NetworkSet] network_set
      # @return [TopologyOperator::NetworkSet]
      def other_policy_check(network_set)
        case network_set.network_name
        when /layer3$/i
          # add flags for layer3
          l3_additional_policy_check(network_set)
        when /ospf_area\d+/i
          # add flags for ospf-area
          ospf_additional_policy_check(network_set)
        else
          network_set
        end
      end

      # Remove node/tp, link which has "deleted" diff_state
      # @return [void]
      def remove_deleted_state_elements!
        @nodes.delete_if { |node| node.diff_state.detect == :deleted }
        @nodes.each do |node|
          node.termination_points.delete_if { |tp| tp.diff_state.detect == :deleted }
        end
        @links.delete_if { |link| link.diff_state.detect == :deleted }
      end

      # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

      # @param [Node] src_node (Source) Node
      # @param [TermPoint] src_tp (Source) Term-point
      # @param [NetworkSubset] nw_subset Connected node and term-point paths (as sub-graph)
      # @return [void]
      def find_connected_nodes_recursively(src_node, src_tp, nw_subset)
        nw_subset.elements.push(src_node.path, src_tp.path)
        link = find_link_by_source(src_node.name, src_tp.name)
        return unless link

        dst_node = find_node_by_name(link.destination.node_ref)
        return unless dst_node

        dst_tp = dst_node.find_tp_by_name(link.destination.tp_ref)
        return unless dst_tp

        # node is pushed multiple times: need `uniq`
        nw_subset.elements.push(dst_node.path, dst_tp.path)

        # stop recursive search if  destination node is endpoint node
        return if @name =~ /layer3/i && dst_node.attribute.node_type == 'endpoint'

        # select term-point and search recursively setting the destination node/tp as source
        dst_node.termination_points.each do |next_src_tp|
          # ignore dst_tp itself
          next if next_src_tp.name == dst_tp.name

          # loop detection
          if nw_subset.elements.include?(next_src_tp.path)
            nw_subset.flag[:loop] = true
            next
          end

          find_connected_nodes_recursively(dst_node, next_src_tp, nw_subset)
        end
      end
      # rubocop:enable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    end
    # rubocop:enable Metrics/ClassLength
  end
end
