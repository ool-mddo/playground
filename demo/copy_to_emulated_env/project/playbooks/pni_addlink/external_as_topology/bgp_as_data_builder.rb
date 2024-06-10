# frozen_string_literal: true

require 'netomox'

require_relative 'bgp_proc_data_builder'

# bgp_as network data builder
class BgpASDataBuilder
  # @param [String] params_file Params file path
  # @param [String] flow_data_file Flow data file path
  # @param [String] api_proxy API proxy (host:port str)
  # @param [String] network_name Network name
  def initialize(params_file, flow_data_file, api_proxy, network_name)
    # each external-AS topology which contains layer3/bgp_proc layer
    @src_topo_builder = BgpProcDataBuilder.new(:source_as, params_file, flow_data_file, api_proxy, network_name)
    @dst_topo_builder = BgpProcDataBuilder.new(:dest_as, params_file, flow_data_file, api_proxy, network_name)

    # target external-AS topology (empty)
    # src/dst ext-AS topology (layer3/bgp-proc) are merged into it with a new layer, bgp_as.
    @ext_as_topology = Netomox::PseudoDSL::PNetworks.new
    # internal-AS topology data (Netomox::Topology::Networks)
    @int_as_topology = @src_topo_builder.int_as_topology
  end

  # @return [Hash] External-AS topology data (rfc8345)
  def build_topology
    merge_ext_topologies!([@src_topo_builder, @dst_topo_builder].map(&:topology))
    make_ext_as_bgp_as_nw!

    @ext_as_topology.interpret.topo_data
  end

  private

  # @param [Array<Netomox::PseudoDSL::PNetworks>] src_ext_as_topologies Src/Dst Ext-AS topologies (layer3/bgp-proc)
  # @return [void]
  def merge_ext_topologies!(src_ext_as_topologies)
    # merge
    %w[layer3 bgp_proc].each do |layer|
      src_ext_as_topologies.each do |src_ext_as_topology|
        src_network = src_ext_as_topology.network(layer)
        dst_network = @ext_as_topology.network(layer)

        dst_network.type = src_network.type
        dst_network.attribute = src_network.attribute

        dst_network.nodes.append(*src_network.nodes)
        dst_network.links.append(*src_network.links)
      end
    end
  end

  # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

  # @return [void]
  def make_ext_as_bgp_as_nw!
    # bgp_as network
    bgp_as_nw = @ext_as_topology.network('bgp_as')
    bgp_as_nw.type = Netomox::NWTYPE_MDDO_BGP_AS
    bgp_as_nw.attribute = { name: 'mddo-bgp-as-network' }

    int_asn = @src_topo_builder.as_state[:int_asn]
    ext_asn_list = [@src_topo_builder.as_state[:ext_asn], @dst_topo_builder.as_state[:ext_asn]].map(&:to_i)

    # internal-AS node
    int_bgp_as_node = bgp_as_nw.node("as#{int_asn}")
    int_bgp_as_node.attribute = { as_number: int_asn }
    int_bgp_proc_nw = @int_as_topology.find_network('bgp_proc')
    int_bgp_as_node.supports = int_bgp_proc_nw.nodes.map { |node| ['bgp_proc', node.name] }

    # external-AS node
    ext_bgp_proc_nw = @ext_as_topology.network('bgp_proc')
    ext_asn_list.each do |ext_asn|
      ext_bgp_as_node = bgp_as_nw.node("as#{ext_asn}")
      ext_bgp_as_node.attribute = { as_number: ext_asn }

      support_bgp_proc_nodes = ext_bgp_proc_nw.nodes.filter { |node| node.tps[0].attribute[:local_as] == ext_asn }
      ext_bgp_as_node.supports = support_bgp_proc_nodes.map { |node| ['bgp_proc', node.name] }

      # inter-as-node (inter-AS) links
      # (no links between ext-ext, there are only ext-int links)
      support_bgp_proc_nodes.each do |ext_bgp_proc_node|
        ext_bgp_proc_node.tps.each do |ext_bgp_proc_tp|
          next unless ext_bgp_proc_tp.attribute.key?(:flags)

          peer_flag = ext_bgp_proc_tp.attribute[:flags].find { |f| f =~ /^ebgp-peer=.+$/ }
          next unless peer_flag

          match = peer_flag.split('=')[-1].match(/(?<node>.+)\[(?<tp>.+)\]/)
          peer_int_node = match[:node]
          peer_int_tp = match[:tp]

          # term-point
          ext_bgp_as_tp = ext_bgp_as_node.term_point(ext_bgp_proc_tp.name)
          ext_bgp_as_tp.supports.push(['bgp_proc', ext_bgp_proc_node.name, ext_bgp_proc_tp.name])
          int_bgp_as_tp = int_bgp_as_node.term_point(peer_int_tp)
          int_bgp_as_tp.supports.push(['bgp_proc', peer_int_node, peer_int_tp])

          # link (bidirectional)
          bgp_as_nw.link(int_bgp_as_node.name, int_bgp_as_tp.name, ext_bgp_as_node.name, ext_bgp_as_tp.name)
          bgp_as_nw.link(ext_bgp_as_node.name, ext_bgp_as_tp.name, int_bgp_as_node.name, int_bgp_as_tp.name)
        end
      end
    end
  end
  # rubocop:enable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
end
