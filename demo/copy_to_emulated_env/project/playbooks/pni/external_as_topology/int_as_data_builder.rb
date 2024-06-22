# frozen_string_literal: true

require 'netomox'
require 'ipaddr'
require 'net/http'
require 'yaml'

# Internal-AS peer data builder
class IntASDataBuilder
  # @!attribute [r] as_state
  #   @return [Hash]
  # @!attribute [r] int_as_topology
  #   @return [Netomox::Topology::Networks]
  attr_reader :as_state, :int_as_topology

  # @param [Symbol] as_type (enum: [source_as, :dest_as])
  # @param [String] params_file Params file path
  # @param [String] api_proxy API proxy (host:port str)
  # @param [String] network_name Network name
  def initialize(as_type, params_file, api_proxy, network_name)
    # self (internal) AS topology
    int_as_topology_data = fetch_int_as_topology(api_proxy, network_name)
    @int_as_topology = Netomox::Topology::Networks.new(int_as_topology_data)

    # single (target) as params
    all_params = read_params_file(params_file)
    @params = all_params[as_type.to_s]
    # peer info
    @peer_list = find_all_peers(@params['asn'])
    # target AS info
    @as_state = make_as_state(as_type)
  end

  private

  # @param [Symbol] as_type (enum: [source_as, :dest_as])
  # @return [Hash] as_state
  def make_as_state(as_type)
    {
      type: as_type,
      int_asn: @peer_list.map { |item| item[:bgp_proc][:local_as] }.uniq[0],
      ext_asn: @peer_list.map { |item| item[:bgp_proc][:remote_as] }.uniq[0]
    }
  end

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

  # @param [Netomox::Topology::TermPoint] bgp_proc_tp Internal-AS eBGP term-point
  # @param [Integer] remote_asn Remote ASN
  # @return [Boolean] true if target eBGP edge
  def target_ebgp_peer?(bgp_proc_tp, remote_asn)
    tp_attr = bgp_proc_tp.attribute
    tp_attr.remote_as == remote_asn && @params['allowed_peers'].include?(tp_attr.remote_ip)
  end

  # @param [Netomox::Topology::Node] bgp_proc_node Internal-AS eBGP node
  # @param [Netomox::Topology::TermPoint] bgp_proc_tp Internal-AS eBGP term-point
  # @return [Hash] peer_item
  def make_peer_item(bgp_proc_node, bgp_proc_tp)
    tp_attr = bgp_proc_tp.attribute
    layer3_ref = bgp_proc_tp.supports.find { |s| s.ref_network == 'layer3' }
    {
      bgp_proc: {
        node_name: bgp_proc_node.name,
        tp_name: bgp_proc_tp.name,
        local_as: tp_attr.confederation.negative? ? tp_attr.local_as : tp_attr.confederation,
        local_ip: tp_attr.local_ip,
        remote_as: tp_attr.remote_as,
        remote_ip: tp_attr.remote_ip
      },
      layer3: {
        node_name: layer3_ref.ref_node,
        tp_name: layer3_ref.ref_tp,
        ip_addr: find_layer3_tp_ip_addr(layer3_ref.ref_node, layer3_ref.ref_tp)
      }
    }
  end

  # @param [Integer] remote_asn Remote ASN
  # @return [Array<Hash>] peer list
  def find_all_peers(remote_asn)
    peer_list = []
    bgp_proc_nw = @int_as_topology.find_network('bgp_proc')
    bgp_proc_nw.nodes.each do |bgp_proc_node|
      bgp_proc_node.termination_points.each do |bgp_proc_tp|
        next unless target_ebgp_peer?(bgp_proc_tp, remote_asn)

        peer_list.push(make_peer_item(bgp_proc_node, bgp_proc_tp))
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
    #       :remote_as => 65518,          ... NOTICE: confederation
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

  # @param [String] file_path Params file path
  # @return [Hash] params
  def read_params_file(file_path)
    YAML.load_file(file_path)
  rescue Psych::SyntaxError => e
    warn "Error: Failed to parse YAML file: #{e.message}"
    exit 1
  end
end
