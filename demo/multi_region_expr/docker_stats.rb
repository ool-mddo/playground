# frozen_string_literal: true

require 'optparse'
require_relative 'docker_stats_utils'

# @param [Array<String>] names
# @param [Array<Symbol>] cols
# @return [Array<String>] header columns
def header(names, cols)
  header = names.map do |name|
    cols.map do |col|
      "#{col}@#{name}"
    end
  end
  header.flatten
end

##########
# main

opts = ARGV.getopts('', 'dir:', 'datafile', 'max-mem:')

unless opts['dir']
  warn 'Error: Target log directory is not specified'
  warn "  Usage: #{$PROGRAM_NAME} --dir docker_stats_dir [--datafile] [--max-mem container]"
  exit 1
end

stats_log_dir = opts['dir']
docker_stats_log = DockerStatsLog.new(stats_log_dir)

if opts['max-mem']
  container = opts['max-mem']
  puts "Max mem usage of #{container}: #{docker_stats_log.pick_column_of(container, :mem_usage).max}"
  exit 0
end

if opts['datafile']
  # convert stats log to per-stats-column data
  container_names = %w[
    playground-model-conductor-1 playground-netomox-exp-1 playground-batfish-wrapper-1 playground-batfish-1
  ]
  cols = %i[cpu_percent mem_usage mem_percent net_in net_out block_in block_out]

  cols.each do |col|
    File.open("#{stats_log_dir}/#{col}.dat", 'w') do |file|
      file.puts "# #{(%w[time] + header(container_names, [col])).join(', ')}"
      docker_stats_log.time_stats_list.each do |time_stat|
        file.puts time_stat.select(container_names, [col]).flatten.join(', ')
      end
    end
  end
end
