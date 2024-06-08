# frozen_string_literal: true

require 'netomox'

# External-AS topology builder
class ExternalASTopologyBuilder
  private

  # rubocop:disable Metrics/CyclomaticComplexity

  # @return [void]
  def make_ext_as_bgp_as_nw!
    # bgp_proc networks
    ext_bgp_proc_nw = @ext_as_topology.network('bgp_proc')
    int_bgp_proc_nw = @int_as_topology.find_network('bgp_proc')

    # bgp_as network
    bgp_as_nw = @ext_as_topology.network('bgp_as')
    bgp_as_nw.type = Netomox::NWTYPE_MDDO_BGP_AS
    bgp_as_nw.attribute = { name: 'mddo-bgp-as-network' }

    # bgp_as node (ext-as node)
    ext_bgp_as_node = bgp_as_nw.node("as#{@as_state[:ext_asn]}")
    ext_bgp_as_node.attribute = { as_number: @as_state[:ext_asn] }
    ext_bgp_as_node.supports = ext_bgp_proc_nw.nodes.map { |node| ['bgp_proc', node.name] }

    # bgp_as node (int-as node)
    int_bgp_as_node = bgp_as_nw.node("as#{@as_state[:int_asn]}")
    int_bgp_as_node.attribute = { as_number: @as_state[:int_asn] }
    int_bgp_as_node.supports = int_bgp_proc_nw.nodes.map { |node| ['bgp_proc', node.name] }

    # tp/link
    ext_bgp_proc_nw.nodes.each do |ext_bgp_proc_node|
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
  # rubocop:enable Metrics/CyclomaticComplexity
end
