# frozen_string_literal: true

require 'csv'
require 'fileutils'
require 'json'
require 'thor'
require_relative 'linkdown_simulation'

module LinkdownSimulation
  # scenario base class
  class ScenarioBase < Thor

    private

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
      File.open(file_path, 'w') { |file| JSON.dump(data, file) }
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
      else
        puts JSON.pretty_generate(data) # default
      end
    end

    # @param [Array<Array>] data Table data: [[header cols],[data],...]
    # @return [void]
    def print_csv(data)
      CSV do |csv_out|
        data.each { |row| csv_out << row }
      end
    end

    # @param [Array<Array>] data Table data: [[header cols],[data],...]
    # @param [String] file_name File name to write
    # @return [void]
    def save_csv_file(data, file_name)
      CSV.open(file_name, 'wb') do |csv_out|
        data.each { |row| csv_out << row }
      end
    end
  end
end
