# frozen_string_literal: true

require 'netomox'

# External-AS topology builder
class ExternalASTopologyBuilder
  private

  # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

  # @return [void]
  def make_ext_as_bgp_as_nw!
    # bgp_as network
    bgp_as_nw = @ext_as_topology.network('bgp_as')
    bgp_as_nw.type = Netomox::NWTYPE_MDDO_BGP_AS
    bgp_as_nw.attribute = { name: 'mddo-bgp-as-network' }

    int_asn = @as_state[:int_asn]
    ext_asn_list = [@params['source_as']['asn'], @params['dest_as']['asn']].map(&:to_i)

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
