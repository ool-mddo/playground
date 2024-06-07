# frozen_string_literal: true

require 'netomox'
require 'ipaddr'

# External-AS topology builder
class ExternalASTopologyBuilder
  private

  # @param [String] api_proxy
  # @param [String] network_name
  # @return [Hash] Internal-AS topology data (rfc8345)
  def fetch_int_as_topology(api_proxy, network_name)
    url = URI("http://#{api_proxy}/topologies/#{network_name}/original_asis/topology")
    response = Net::HTTP.get_response(url)
    response.is_a?(Net::HTTPSuccess) ? JSON.parse(response.body) : { error: response.message }
  end

  # @param [String] layer3_node_name
  # @param [String] layer3_tp_name
  # @return [String] ip address of the interface
  def find_layer3_tp_ip_addr(layer3_node_name, layer3_tp_name)
    layer3_nw = @int_as_topology.find_network('layer3')
    layer3_node = layer3_nw.find_node_by_name(layer3_node_name)
    layer3_tp = layer3_node.find_tp_by_name(layer3_tp_name)
    layer3_tp.attribute.ip_addrs[0]
  end

  # @param [Integer] remote_asn Remote ASN
  # @return [Array<Hash>] peer list
  def find_all_peers(remote_asn)
    peer_list = []
    bgp_proc_nw = @int_as_topology.find_network('bgp_proc')
    bgp_proc_nw.nodes.each do |bgp_proc_node|
      bgp_proc_node.termination_points.each do |bgp_proc_tp|
        bgp_proc_attr = bgp_proc_tp.attribute
        next unless bgp_proc_attr.remote_as == remote_asn

        layer3_ref = bgp_proc_tp.supports.find { |s| s.ref_network == 'layer3' }
        peer_item = {
          bgp_proc: {
            node_name: bgp_proc_node.name,
            tp_name: bgp_proc_tp.name,
            local_as: bgp_proc_attr.local_as,
            local_ip: bgp_proc_attr.local_ip,
            remote_as: bgp_proc_attr.remote_as,
            remote_ip: bgp_proc_attr.remote_ip
          },
          layer3: {
            node_name: layer3_ref.ref_node,
            tp_name: layer3_ref.ref_tp,
            ip_addr: find_layer3_tp_ip_addr(layer3_ref.ref_node, layer3_ref.ref_tp)
          }
        }
        peer_list.push(peer_item)
      end
    end
    # [                                   ... peer_list
    #   {                                 ... peer_item
    #     :bgp_proc => {
    #       :node_name => "192.168.255.5",
    #       # :node => Netomox::PseudoDSL::PNode  ... bgp_proc node
    #       :tp_name => "peer_172.16.0.5",
    #       :local_as => 65500,
    #       :local_ip => "172.16.0.6",
    #       :remote_as => 65550,
    #       :remote_ip => "172.16.0.5"
    #     },
    #     :layer3 => {
    #       :node_name => "edge-tk01",
    #       # :node => Netomox::PseudoDSL::PNode  ... layer3 node
    #       :tp_name => "ge-0/0/3.0",
    #       :ip_addr => "172.16.0.6/30"
    #     }
    #   },
    #   ...
    # ]
    peer_list
  end
end
