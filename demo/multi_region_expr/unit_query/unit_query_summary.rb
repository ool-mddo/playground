# frozen_string_literal: true

require 'json'

data = []
ARGF.each_line do |line|
  line.chomp!

  if /# branch (?<branch>.+)/ =~ line
    data.push({ branch: branch })
    next
  end

  if /## cmd: (?<test_type>.+)/ =~ line
    result = { test_type: test_type }
    if data[-1][:results]
      data[-1][:results].push(result)
    else
      data[-1][:results] = [result]
    end
    next
  end

  if /real (?<real>[\d.]+), user (?<user>[\d.]+), sys (?<sys>[\d.]+)/ =~ line
    if data[-1][:results]
      data[-1][:results][-1][:real] = real
      data[-1][:results][-1][:user] = user
      data[-1][:results][-1][:sys] = sys
    else
      warn 'Error: results not found'
    end
  end
end

# for debug
# puts JSON.dump(data)

value_keys = %w[topology_generate single_snapshot_queries tracert_neighbor_region tracert_facing_region]
header = %w[branch region] + value_keys
puts "# #{header.join(', ')}"
data.each do |datum|
  values = value_keys.map do |key|
    time_data = datum[:results].find { |d| d[:test_type] == key }
    time_data[:real]
  end
  region = if /(?<region>\d+)regiondemo/ =~ datum[:branch]
             region.to_i
           else
             2
           end
  puts ([datum[:branch], region] + values).join(', ')
end
