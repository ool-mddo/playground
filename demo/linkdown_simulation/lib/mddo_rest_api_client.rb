# frozen_string_literal: true

require 'json'
require 'httpclient'

module LinkdownSimulation
  # http client for linkdown simulation
  class MddoRestApiClient
    API_HOST = ENV.fetch('MDDO_API_HOST', 'localhost:15000')

    # @param [Logger] logger
    def initialize(logger)
      @logger = logger
      @http_client = HTTPClient.new
      @http_client.receive_timeout = 60 * 60 * 4 # 60sec * 60min * 4h
    end

    # @param [String] api_path PATH of REST API
    # @param [Hash] data Data to post
    # @return [HTTP::Message,nil] Reply
    def post(api_path, data = {})
      header = { 'Content-Type' => 'application/json' }
      body = JSON.generate(data)
      str_limit = 80
      data_str = data.to_s.length < str_limit ? data.to_s : "#{data.to_s[0, str_limit - 3]}..."
      url = "http://#{API_HOST}/#{api_path}"
      @logger.info "POST: #{url}, data=#{data_str}"
      response = @http_client.post(url, body:, header:)
      warn "# [ERROR] #{response.status} < POST #{url}, data=#{data_str}" if error_response?(response)
      response
    end

    # @param [String] api_path PATH of REST API
    # @param [Hash] param GET parameter
    # @return [HTTP::Message,nil] Reply
    def fetch(api_path, param = {})
      url = "http://#{API_HOST}/#{api_path}"
      @logger.info "GET: #{url}, param=#{param}"
      response = param.empty? ? @http_client.get(url) : @http_client.get(url, query: param)
      warn "# [ERROR] #{response.status} < GET #{url}" if error_response?(response)
      response
    end

    # @param [String] network Network name
    # @param [String] snapshot Snapshot name
    # @return [Hash, nil] topology data
    def fetch_topology_data(network, snapshot)
      url = "/topologies/#{network}/#{snapshot}/topology"
      response = fetch(url)
      return nil if error_response?(response)

      # NOTICE: DO NOT symbolize
      response_data = JSON.parse(response.body, { symbolize_names: false })
      response_data['topology_data']
    end

    # @param [String] network Network name
    # @param [String] snapshot Snapshot name
    # @return [Array<Hash>, nil] snapshot patterns
    def fetch_snapshot_patterns(network, snapshot)
      url = "/configs/#{network}/#{snapshot}/snapshot_patterns"
      response = fetch(url)
      return {} if error_response?(response)

      JSON.parse(response.body, { symbolize_names: true })
    end

    # @return [Array<String>,nil] networks
    def fetch_networks
      response = fetch('/batfish/networks')
      fetch_response(response)
    end

    # @param [String] network Network name
    # @param [Boolean] simulated Enable to get all simulated snapshots
    # @return [Array<String>,nil] snapshots
    def fetch_snapshots(network, simulated = false)
      url = "/batfish/#{network}/snapshots"
      response = simulated ? fetch(url, { 'simulated' => true }) : fetch(url)
      fetch_response(response)
    end

    # @param [String] network Network name
    # @param [String] snapshot Snapshot name
    # @return [String,nil] json string
    def fetch_all_interface_list(network, snapshot)
      # - node: str
      #   interface: str
      #   addresses: []
      # - ...
      response = fetch("/batfish/#{network}/#{snapshot}/interfaces")
      fetch_response(response)
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
      response = fetch(url, param)
      fetch_response(response)
    end

    private

    # @param [HTTP::Message] response HTTP response
    # @return [Boolean]
    def error_response?(response)
      # Error when status code is not 2xx
      response.status % 100 == 2
    end

    # @param [HTTP::Message] response HTTP response
    # @return [Object, nil]
    def fetch_response(response)
      error_response?(response) ? nil : JSON.parse(response.body, { symbolize_names: true })
    end
  end
end
