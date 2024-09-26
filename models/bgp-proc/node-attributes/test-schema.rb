#!/usr/bin/env ruby

# This script is used to test the json schemas
# usage: ruby test-schema.rb schema.json data.json

require 'json'
require 'json-schema'

if ARGV.length != 2
    puts "Usage: ruby test-schema.rb schema.json data.json"
    exit 1
  end

  # Load the schema and data from the provided files
  schema_file = ARGV[0]
  data_file = ARGV[1]

  begin
    schema = JSON.parse(File.read(schema_file))
    data = JSON.parse(File.read(data_file))

    # Validate the data against the schema
    JSON::Validator.validate!(schema, data)

    puts "Data is valid according to the schema."
  rescue JSON::Schema::ValidationError => e
    puts "Data is not valid according to the schema. Error: #{e.message}"
  rescue => e
    puts "An error occurred: #{e.message}"
  end