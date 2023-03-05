# frozen_string_literal: true

require 'httpclient'
require 'json'

module LinkdownSimulation
  # Batfish-Wrapper Query base: base class to query batfish via batfish-wrapper
  class BFWrapperQueryBase
    def initialize
      @client = HTTPClient.new
    end

    protected

    # @param [String] api API string
    # @param [Hash] param GET parameter
    # @return [Object,nil] JSON parsed object
    def bfw_query(api, param = {})
      batfish_wrapper = ENV.fetch('BATFISH_WRAPPER_HOST', nil) || 'localhost:5000'
      url = "http://#{[batfish_wrapper, api].join('/').gsub(%r{/+}, '/')}"

      # # debug
      # param_str = param.each_key.map { |k| "#{k}=#{param[k]}" }.join('&')
      # warn "# url = #{param.empty? ? url : [url, param_str].join('?')}"

      res = param.empty? ? @client.get(url) : @client.get(url, query: param)
      res.status == 200 ? JSON.parse(res.body, { symbolize_names: true }) : nil
    end

    # @param [String] network Network name
    # @param [String] snapshot Snapshot name
    # @return [String,nil] json string
    def fetch_all_interface_list(network, snapshot)
      # - node: str
      #   interface: str
      #   addresses: []
      # - ...
      bfw_query("/batfish//#{network}/#{snapshot}/interfaces")
    end

    # @param [String] network Network name in batfish
    # @param [String] snapshot Snapshot name in network
    # @param [String] src_node Source-node name
    # @param [String] src_intf Source-interface name
    # @param [String] dst_ip Destination IP address
    # @return [Hash,nil]
    def fetch_traceroute(network, snapshot, src_node, src_intf, dst_ip)
      url = "/batfish/#{network}/#{snapshot}/#{src_node}/traceroute"
      param = { 'interface' => src_intf, 'destination' => dst_ip }

      # network: str
      # snapshot: str
      # result:
      #   - Flow: {}
      #     Traces: []
      #   - ...
      bfw_query(url, param)
    end

    # @return [Array<String>,nil] networks
    def fetch_networks
      bfw_query('/api/networks')
    end

    # @param [String] network Network name
    # @param [Boolean] simulated Enable to get all simualted snapshots
    # @return [Array<String>,nil] snapshots
    def fetch_snapshots(network, simulated)
      url = "/batfish/#{network}/snapshots"
      url = [url, 'simulated=true'].join('?') if simulated
      bfw_query(url)
    end

    # @param [String] network Network name
    # @param [String] snapshot Snapshot name
    # @return [Array<Hash>,Hash,nil]
    def fetch_snapshot_pattern(network, snapshot)
      url = "/configs/#{network}/#{snapshot}/snapshot_patterns"
      bfw_query(url)
    end
  end
end
