# frozen_string_literal: true

require_relative 'docker_stats_utils'

class StatsExec
  attr_reader :branch, :region, :link

  def initialize(log_dir)
    @log_dir = log_dir
    @exec_log_file = File.join(log_dir, 'exec.log')
    @time_table = {}
    @branch = ''
    read_exec_log
    @region = add_data_by_branch
    @link = 18 * @region
  end

  # accessor
  def values(keys)
    keys.map { |hk| @time_table[hk] }
  end

  def bf_max_mem_usage
    stats_log = DockerStatsLog.new(@log_dir)
    stats_log.pick_column_of('playground_batfish_1', :mem_usage).max
  end

  private

  def add_data_by_branch
    match = @branch.match(/(?<region>\d+)region*/)
    match ? match[:region].to_i : 2
  end

  def read_exec_log
    File.open(@exec_log_file, 'r') do |file|
      file.each_line do |line|
        line.chomp!
        match = line.match(/(?<point>BEGIN|END) CONFIGS: (?<branch>\S+), (?<time>[\d\.]+)/)
        if match
          key = "total_#{match[:point]}".downcase.intern
          @time_table[key] = match[:time].to_f
          @branch = match[:branch]
          next
        end

        match = line.match(/(?<point>BEGIN|END) TASK: (?<task>\S+), (?<time>[\d\.]+)/)
        if match
          key = "#{match[:task]}_#{match[:point]}".downcase.intern
          @time_table[key] = match[:time].to_f
        end
      end
    end
  end
end

##########
# main

if ARGV.length == 0
  warn 'Error: Target log directory is not specified'
  warn "  Usage: #{$PROGRAM_NAME} --dir docker_stats_dir [dir ...]"
  exit 1
end

stats_execs = ARGV.map { |stats_dir| StatsExec.new(stats_dir) }
header = %w[total model_dirs simulation_pattern snapshot_to_model netoviz_index netoviz_model netoviz_layout netomox_diff]

puts '# ' + %i[branch region link bf_max_mem_usage].concat(header).map(&:to_s).join(', ')
stats_execs.each do |stats_exec|
  diff_values = header.map {|hk| stats_exec.values(%W[#{hk}_begin #{hk}_end].map(&:intern))}
                      .map {|time_pair| (time_pair[1] - time_pair[0]).round(2) }
  values = [stats_exec.branch, stats_exec.region, stats_exec.link, stats_exec.bf_max_mem_usage]
  puts values.concat(diff_values).join(', ')
end
