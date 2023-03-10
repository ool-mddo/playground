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

    private

    # @param [HTTP::Message] response HTTP response
    # @return [Boolean]
    def error_response?(response)
      # Error when status code is not 2xx
      response.status / 100 != 2
    end
  end
end
