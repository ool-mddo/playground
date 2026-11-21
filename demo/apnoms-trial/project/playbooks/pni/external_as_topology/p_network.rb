# frozen_string_literal: true

require 'netomox'

module Netomox
  module PseudoDSL
    # pseudo network
    class PNetwork
      # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/AbcSize

      # @param [String] node1 Node1 name
      # @param [String] node2 Node2 name
      # @return [nil, PLink]
      def find_link_between_node(node1, node2)
        # pattern:
        #   node1 [tp1] -------------------- [tp2] node2
        #   node1 [tp1] -- [] seg_node [] -- [tp2] node2
        # return: Link: node1 [tp1] -- [tp2] node2
        node1_dst_nodes = find_all_links_by_src_name(node1).map { |link| link.dst.node }
        node2_dst_nodes = find_all_links_by_src_name(node2).map { |link| link.dst.node }
        mid_nodes = node1_dst_nodes & node2_dst_nodes

        if mid_nodes.empty? && node1_dst_nodes.include?(node2) && node2_dst_nodes.include?(node1)
          # direct connected
          @links.find { |link| link.src.node == node1 && link.dst.node == node2 }
        elsif !mid_nodes.empty?
          # node-seg-node pattern
          mid_node = mid_nodes[0]
          link1 = @links.find { |link| link.src.node == node1 && link.dst.node == mid_node }
          link2 = @links.find { |link| link.src.node == mid_node && link.dst.node == node2 }
          PLink.new(link1.src, link2.dst)
        end
      end
      # rubocop:enable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/AbcSize

      # @param [PNode] node (upper layer node)
      # @return [PNode, nil] supported node
      def find_supporting_node(node)
        support = node.supports.find { |s| s[0] == @name }
        node(support[1])
      end
    end
  end
end
