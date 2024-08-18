require 'optparse'
require 'csv'
require 'yaml'
require 'json'

def read_csv(file)
  csv_data = CSV.read(file, headers: true)
  csv_data.map(&:to_h)
end

def read_yaml(file)
  YAML.load_file(file)
end

def output_json(json_data, file)
  if file
    File.open(file, "w") { |f| f.write(json_data) }
  else
    puts json_data
  end
end

options = { output: nil }
OptionParser.new do |opts|
  opts.banner = "Usage: #{$0} [options]"
  opts.on("-c", "--csv CSV_FILE", "CSV file to read") do |csv_file|
    options[:csv] = csv_file
  end
  opts.on("-y", "--yaml YAML_FILE", "YAML file to read") do |yaml_file|
    options[:yaml] = yaml_file
  end
  opts.on("-o", "--output OUTPUT_FILE", "Output file (optional)") do |output_file|
    options[:output] = output_file
  end
end.parse!

# NOTE: exclusive options [-c, -y]
if options[:csv] && options[:yaml]
  warn 'Multiple input files are specified. Choise CSV or YAML as input'
  exit 1
elsif options[:csv].nil? && options[:yaml].nil?
  warn "No data to convert. Please provide either a CSV or YAML file."
  exit 1
end

data = options[:csv] ? read_csv(options[:csv]) : read_yaml(options[:yaml])
json_data = JSON.generate(data) # compact
output_json(json_data, options[:output])
