# frozen_string_literal: true

require 'netomox'

# @param [Netomox::PseudoDSL::Networks] ext_as_topology Topology object of external-AS
# @param [Netomox::Topology::Networks] int_as_topology Topology object of internal-AS
# @param [Array<Hash>] peer_list Peer list
# @return [void]
def make_ext_as_bgp_as_nw(ext_as_topology, int_as_topology, peer_list)
  # bgp_proc networks
  ext_bgp_proc_nw = ext_as_topology.network('bgp_proc')
  int_bgp_proc_nw = int_as_topology.find_network('bgp_proc')

  # bgp_as network
  bgp_as_nw = ext_as_topology.network('bgp_as')
  bgp_as_nw.type = Netomox::NWTYPE_MDDO_BGP_AS
  bgp_as_nw.attribute = { name: 'mddo-bgp-as-network' }

  # bgp_as node (ext-as node)
  ext_asn = peer_list.map { |item| item[:bgp_proc][:remote_as] }.uniq[0]
  ext_bgp_as_node = bgp_as_nw.node("as#{ext_asn}")
  ext_bgp_as_node.attribute = { as_number: ext_asn }
  ext_bgp_proc_nw.nodes.each do |ext_bgp_proc_node|
    ext_bgp_as_node.supports.push(['bgp_proc', ext_bgp_proc_node.name])
  end

  # bgp_as node (int-as node)
  int_asn = peer_list.map { |item| item[:bgp_proc][:local_as] }.uniq[0]
  int_bgp_as_node = bgp_as_nw.node("as#{int_asn}")
  int_bgp_as_node.attribute = { as_number: int_asn }
  int_bgp_proc_nw.nodes.each do |int_bgp_proc_node|
    int_bgp_as_node.supports.push(['bgp_proc', int_bgp_proc_node.name])
  end

  # tp/link
  ext_bgp_proc_nw.nodes.each do |ext_bgp_proc_node|
    ext_bgp_proc_node.tps.each do |ext_bgp_proc_tp|
      warn "# DEBUG: ext_bgp_proc_node=#{ext_bgp_proc_node.name}, tp=#{ext_bgp_proc_tp.name}, attr=#{ext_bgp_proc_tp.attribute}"
      next unless ext_bgp_proc_tp.attribute.key?(:flags)

      peer_flag = ext_bgp_proc_tp.attribute[:flags].find { |f| f =~ %r{^ebgp-peer=.+$}}
      warn "# DEBUG: peer_flag = #{peer_flag}"
      next unless peer_flag

      match = peer_flag.split('=')[-1].match(%r{(?<node>.+)\[(?<tp>.+)\]})
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
