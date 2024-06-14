# frozen_string_literal: true

require 'csv'
require 'ipaddr'
require 'netomox'

require_relative 'int_as_data_builder'
require_relative 'ip_addr_management'

# Layer3 network data builder
class Layer3DataBuilder < IntASDataBuilder
  # @param [Symbol] as_type (enum: [source_as, :dest_as])
  # @param [String] params_file Params file path
  # @param [String] flow_data_file Flow data file path
  # @param [String] api_proxy API proxy (host:port str)
  # @param [String] network_name Network name
  def initialize(as_type, params_file, flow_data_file, api_proxy, network_name)
    super(as_type, params_file, api_proxy, network_name)

    flow_data = read_flow_data_file(flow_data_file)
    @flow_list = column_items_from_flows(flow_data)

    @ipam = IPAddrManagement.instance # singleton
    @ipam.assign_base_prefix(@params['subnet'])

    # target external-AS topology (empty)
    @ext_as_topology = Netomox::PseudoDSL::PNetworks.new

    # layer3 network
    @layer3_nw = @ext_as_topology.network('layer3')
    @layer3_nw.type = Netomox::NWTYPE_MDDO_L3
    @layer3_nw.attribute = { name: 'mddo-layer3-network' }

    make_layer3_topology!
  end

  private

  # @return [void]
  def add_layer3_ebgp_routers
    # add ebgp-speakers
    @peer_list.each_with_index do |peer_item, peer_index|
      # inter-AS segment ip
      # NOTE: IPAddr.new("172.16.0.6/30") => #<IPAddr: IPv4:172.16.0.4/255.255.255.252>
      seg_ip = IPAddr.new(peer_item[:layer3][:ip_addr])

      # layer3 edge-router node
      node_name = layer3_router_name(format('edge%02d', peer_index + 1))
      layer3_node = @layer3_nw.node(node_name)
      peer_item[:layer3][:node] = layer3_node # memo
      layer3_node.attribute = {
        node_type: 'node',
        prefixes: [{ prefix: "#{seg_ip}/#{seg_ip.prefix}", metric: 0, flags: ['connected'] }]
      }

      # layer3 edge-router term-point
      layer3_tp = layer3_node.term_point('Ethernet0')
      layer3_tp.attribute = {
        ip_addrs: ["#{peer_item[:bgp_proc][:remote_ip]}/#{seg_ip.prefix}"],
        flags: ["ebgp-peer=#{peer_item[:layer3][:node_name]}[#{peer_item[:layer3][:tp_name]}]"]
      }
    end
  end

  # @param [Array<Hash>] peer_item_l3_pair Peer item (layer3 part)
  # @return [void]
  def add_layer3_ibgp_links(peer_item_l3_pair)
    link_ip_str = @ipam.current_link_ip_str # network address
    link_intf_ip_str_pair = @ipam.current_link_intf_ip_str_pair # interface address pair
    node_attr_prefix = { prefix: link_ip_str, metric: 0, flags: ['connected'] } # for node
    seg_attr_prefix = { prefix: link_ip_str, metric: 0 } # for seg_node

    # topology pattern:
    #   node1 [tp1] -- [seg_tp1] seg_node [seg_tp2] -- [tp2] node2

    # target nodes/tp (node1)
    layer3_node1 = peer_item_l3_pair[0][:node]
    layer3_node1.attribute[:prefixes] = [] unless layer3_node1.attribute.key?(:prefixes)
    layer3_node1.attribute[:prefixes].push(node_attr_prefix)
    layer3_tp1 = layer3_node1.term_point("Ethernet#{layer3_node1.tps.length}")
    # target nodes/tp (node2)
    layer3_node2 = peer_item_l3_pair[1][:node]
    layer3_node2.attribute[:prefixes] = [] unless layer3_node2.attribute.key?(:prefixes)
    layer3_node2.attribute[:prefixes].push(node_attr_prefix)
    layer3_tp2 = layer3_node2.term_point("Ethernet#{layer3_node2.tps.length}")

    # segment node/tp
    layer3_seg_node = @layer3_nw.node("Seg_#{@ipam.current_link_ip_str}")
    layer3_seg_node.attribute = { node_type: 'segment', prefixes: [seg_attr_prefix] }
    layer3_seg_tp1 = layer3_seg_node.term_point("#{layer3_node1.name}_#{layer3_tp1.name}")
    layer3_seg_tp2 = layer3_seg_node.term_point("#{layer3_node2.name}_#{layer3_tp2.name}")

    # target tp attribute
    layer3_tp1.attribute = {
      flags: ["ibgp-peer=#{layer3_node2.name}[#{layer3_tp2.name}]"],
      ip_addrs: [link_intf_ip_str_pair[0]]
    }
    layer3_tp2.attribute = {
      flags: ["ibgp-peer=#{layer3_node1.name}[#{layer3_tp1.name}]"],
      ip_addrs: [link_intf_ip_str_pair[1]]
    }

    # src to seg link (bidirectional)
    @layer3_nw.link(layer3_node1.name, layer3_tp1.name, layer3_seg_node.name, layer3_seg_tp1.name)
    @layer3_nw.link(layer3_seg_node.name, layer3_seg_tp1.name, layer3_node1.name, layer3_tp1.name)
    # seg to dst link (bidirectional)
    @layer3_nw.link(layer3_seg_node.name, layer3_seg_tp2.name, layer3_node2.name, layer3_tp2.name)
    @layer3_nw.link(layer3_node2.name, layer3_tp2.name, layer3_seg_node.name, layer3_seg_tp2.name)

    # next link-ip
    @ipam.count_link
  end

  # @param [String] flow_item Prefix (e.g. a.b.c.d/xx)
  # @return [Hash]
  # @raise [StandardError] Endpoint segment is too small
  def flow_addr_table(flow_item)
    seg_addr = IPAddr.new(flow_item)
    raise StandardError, "Endpoint segment is too small (>/25), #{flow_item}" if seg_addr.prefix > 25

    router_addr = seg_addr | '0.0.0.1'
    endpoint_addr = seg_addr | '0.0.0.100' # MUST prefix <= /25

    {
      seg_addr: seg_addr.to_s,
      seg_addr_prefix: "#{seg_addr}/#{seg_addr.prefix}",
      router_addr: router_addr.to_s,
      router_addr_prefix: "#{router_addr}/#{router_addr.prefix}",
      endpoint_addr: endpoint_addr.to_s,
      endpoint_addr_prefix: "#{endpoint_addr}/#{endpoint_addr.prefix}"
    }
  end

  # @param [Netomox::PseudoDSL::PNode] layer3_core_node Layer3 core node
  # @param [String] src_flow_item Flow source prefix
  # @param [Integer] src_flow_index Flow source index
  def add_layer3_core_to_endpoint_links(layer3_core_node, src_flow_item, src_flow_index)
    addrs = flow_addr_table(src_flow_item)
    node_attr_prefix = { prefix: addrs[:seg_addr_prefix], metric: 0, flags: ['connected'] } # for node
    seg_attr_prefix = { prefix: addrs[:seg_addr_prefix], metric: 0 } # for seg_node

    # topology pattern:
    #   endpoint [tp] -- [seg_tp1] seg_node [seg_tp2] -- [tp] core

    # core node-attr/tp
    layer3_core_node.attribute[:prefixes] = [] unless layer3_core_node.attribute.key?(:prefixes)
    layer3_core_node.attribute[:prefixes].push(node_attr_prefix)
    core_tp_index = layer3_core_node.tps.length
    layer3_core_tp = layer3_core_node.term_point("Ethernet#{core_tp_index}")
    layer3_core_tp.attribute = { ip_addrs: [addrs[:router_addr_prefix]] }

    # endpoint node/tp
    ep_name = layer3_router_name(format('endpoint%02d', src_flow_index))
    layer3_endpoint_node = @layer3_nw.node(ep_name)
    layer3_endpoint_node.attribute = {
      node_type: 'endpoint',
      static_routes: [
        { prefix: '0.0.0.0/0', next_hop: addrs[:router_addr], interface: 'Ethernet0', description: 'default-route' }
      ],
      prefixes: [node_attr_prefix]
    }
    layer3_endpoint_tp = layer3_endpoint_node.term_point('Ethernet0')
    layer3_endpoint_tp.attribute = { ip_addrs: [addrs[:endpoint_addr_prefix]] }

    # segment node/tp
    layer3_seg_node = @layer3_nw.node("Seg_#{addrs[:seg_addr_prefix]}")
    layer3_seg_node.attribute = { node_type: 'segment', prefixes: [seg_attr_prefix] }
    layer3_seg_tp1 = layer3_seg_node.term_point("#{layer3_core_node.name}_#{layer3_core_tp.name}")
    layer3_seg_tp2 = layer3_seg_node.term_point("#{layer3_endpoint_node.name}_#{layer3_endpoint_tp.name}")

    # core-seg link (bidirectional)
    @layer3_nw.link(layer3_core_node.name, layer3_core_tp.name, layer3_seg_node.name, layer3_seg_tp1.name)
    @layer3_nw.link(layer3_seg_node.name, layer3_seg_tp1.name, layer3_core_node.name, layer3_core_tp.name)
    # seg-endpoint link (bidirectional)
    @layer3_nw.link(layer3_seg_node.name, layer3_seg_tp2.name, layer3_endpoint_node.name, layer3_endpoint_tp.name)
    @layer3_nw.link(layer3_endpoint_node.name, layer3_endpoint_tp.name, layer3_seg_node.name, layer3_seg_tp2.name)
  end

  # @param [String] suffix Router-name suffix
  # @return [String] Router-name
  def layer3_router_name(suffix)
    "as#{@as_state[:ext_asn]}-#{suffix}"
  end

  # @return [Netomox::PseudoDSL::PNode] layer3 core router node
  def add_layer3_core_router
    layer3_core_node = @layer3_nw.node(layer3_router_name('core'))
    layer3_core_node.attribute = { node_type: 'node' }
    layer3_core_node
  end

  # @return [void]
  def make_layer3_topology!
    # add core (aggregation) router
    layer3_core_node = add_layer3_core_router
    # add edge-router (ebgp speaker and inter-AS links)
    add_layer3_ebgp_routers

    # iBGP mesh
    # router [] -- [tp1] Seg_x.x.x.x [tp2] -- [] router
    @peer_list.map { |peer_item| peer_item[:layer3] }
              .append({ node_name: layer3_core_node.name, node: layer3_core_node })
              .combination(2).to_a.each do |peer_item_l3_pair|
      add_layer3_ibgp_links(peer_item_l3_pair)
    end

    # endpoint = iperf node
    # endpoint [] -- [tp1] Seg_y.y.y.y [tp2] -- [] core
    @flow_list.each_with_index do |src_flow_item, src_flow_index|
      add_layer3_core_to_endpoint_links(layer3_core_node, src_flow_item, src_flow_index)
    end
  end

  # @param [String] file_path Flow data file path
  # @return [CSV::Table] flow data
  def read_flow_data_file(file_path)
    CSV.read(file_path, headers: true)
  rescue CSV::MalformedCSVError => e
    warn "Error: Malformed CSV row: #{e.message}"
    exit 1
  end

  # @param [CSV::Table] flow_data Flow data
  # @return [Array<String>] items in specified column
  def column_items_from_flows(flow_data)
    column = @as_state[:type] == :source_as ? 'source' : 'dest'
    flow_data.map { |row| row.to_h[column] }.uniq
  end
end
