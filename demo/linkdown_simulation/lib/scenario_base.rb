# frozen_string_literal: true

require 'httpclient'
require 'json'
require 'thor'

module LinkdownSimulation
  # scenario base class
  class ScenarioBase < Thor
    # HTTP Client
    HTTP_CLIENT = HTTPClient.new
    HTTP_CLIENT.receive_timeout = 60 * 60 * 4 # 60sec * 60min * 4h
    # REST API proxy
    API_HOST = ENV.fetch('MDDO_API_HOST', 'localhost:15000')

    private

    # @param [String] message Print message
    # @return [void]
    def debug_print(message)
      warn "# [DEBUG] #{message}" if options[:debug]
    end

    # @param [HTTP::Message] response HTTP response
    # @return [Boolean]
    def error_response?(response)
      # Error when status code is not 2xx
      response.status % 100 == 2
    end

    # @param [String] api_path PATH of REST API
    # @param [Hash] data Data to post
    # @return [HTTP::Message,nil] Reply
    def mddo_post(api_path, data = {})
      header = { 'Content-Type' => 'application/json' }
      body = JSON.generate(data)
      str_limit = 80
      data_str = data.to_s.length < str_limit ? data.to_s : "#{data.to_s[0, str_limit - 3]}..."
      url = "http://#{API_HOST}/#{api_path}"
      puts "# - POST: #{url}, data=#{data_str}"
      response = HTTP_CLIENT.post(url, body:, header:)
      warn "# [ERROR] #{response.status} < POST #{url}, data=#{data_str}" if error_response?(response)
      response
    end

    # @param [String] api_path PATH of REST API
    # @return [HTTP::Message,nil] Reply
    def mddo_get(api_path)
      url = "http://#{API_HOST}/#{api_path}"
      puts "# - GET: #{url}"
      response = HTTP_CLIENT.get(url)
      warn "# [ERROR] #{response.status} < GET #{url}" if error_response?(response)
      response
    end

    # @param [String] file_path File path
    # @return [Hash,Array] data
    def read_json_file(file_path)
      parse_json_str(File.read(file_path))
    end

    # @param [String] str JSON string
    # @return [Array,Hash] parsed data
    def parse_json_str(str)
      JSON.parse(str, { symbolize_names: true })
    end
  end
end
