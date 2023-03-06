# frozen_string_literal: true

require 'fileutils'
require 'httpclient'
require 'json'
require 'logger'
require 'thor'

module LinkdownSimulation
  # scenario base class
  class ScenarioBase < Thor
    # Logger
    LOGGER = Logger.new($stderr)
    LOGGER.level = Logger::Severity::INFO # default
    LOGGER.progname = 'simulator'

    # HTTP Client
    HTTP_CLIENT = HTTPClient.new
    HTTP_CLIENT.receive_timeout = 60 * 60 * 4 # 60sec * 60min * 4h
    # REST API proxy
    API_HOST = ENV.fetch('MDDO_API_HOST', 'localhost:15000')

    private

    # @param [Symbol] severity Log level
    # @return [void]
    def change_logger_level(severity)
      LOGGER.level =
        case severity
        when :debug then Logger::Severity::DEBUG
        when :err, :error then Logger::Severity::ERROR
        when :fatal then Logger::Severity::FATAL
        when :info then Logger::Severity::INFO
        when :warn, :warning then Logger::Severity::WARN
        else Logger::Severity::UNKNOWN
        end
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
      LOGGER.info "POST: #{url}, data=#{data_str}"
      response = HTTP_CLIENT.post(url, body:, header:)
      warn "# [ERROR] #{response.status} < POST #{url}, data=#{data_str}" if error_response?(response)
      response
    end

    # @param [String] api_path PATH of REST API
    # @return [HTTP::Message,nil] Reply
    def mddo_get(api_path)
      url = "http://#{API_HOST}/#{api_path}"
      LOGGER.info "GET: #{url}"
      response = HTTP_CLIENT.get(url)
      warn "# [ERROR] #{response.status} < GET #{url}" if error_response?(response)
      response
    end

    # @param [String] network Network name
    # @param [String] snapshot Snapshot name
    # @return [Hash] topology data
    def get_topology(network, snapshot)
      url = "/topologies/#{network}/#{snapshot}/topology"
      response = mddo_get(url)
      return {} if error_response?(response)

      # NOTICE: DO NOT symbolize
      response_data = parse_json_str(response.body, symbolize_names: false)
      response_data['topology_data']
    end

    # @param [String] file_path File path
    # @return [Object] data
    def read_json_file(file_path)
      parse_json_str(File.read(file_path))
    end

    # @param [Object] data Data to save
    # @param [String] file_path File to save
    # @return [void]
    def save_json_file(data, file_path)
      FileUtils.mkdir_p(File.dirname(file_path))
      JSON.dump(data, File.open(file_path, 'w'))
    end

    # @param [String] str JSON string
    # @param [Boolean] symbolize_names (Optional, default: true)
    # @return [Object] parsed data
    def parse_json_str(str, symbolize_names: true)
      JSON.parse(str, { symbolize_names: })
    end

    # @param [Object] data Data to print
    # @return [void]
    def print_data(data)
      case options[:format]
      when 'yaml'
        puts YAML.dump(data)
      when 'json'
        puts JSON.pretty_generate(data)
      else
        warn "Unknown format option: #{options[:format]}"
        exit 1
      end
    end
  end
end
