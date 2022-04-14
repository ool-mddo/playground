# frozen_string_literal: true

# single status data of a (single) container
class DockerStat
  attr_reader :line

  TABLE_KEYS = {
    container_id: { index: 0, type: :string },
    name: { index: 1, type: :string },
    cpu_percent: { index: 2, type: :unit_num },
    mem_usage: { index: 3, type: :unit_num },
    mem_limit: { index: 4, type: :unit_num },
    mem_percent: { index: 5, type: :unit_num },
    net_in: { index: 6, type: :unit_num },
    net_out: { index: 7, type: :unit_num },
    block_in: { index: 8, type: :unit_num },
    block_out: { index: 9, type: :unit_num },
    pid: { index: 10, type: :integer }
  }.freeze

  # @param [String] stat_line Docker stat line for a container
  def initialize(stat_line)
    @line = stat_line
    fields = stat_line.split(/\s+/).reject { |e| e == '/' }
    @table = {}
    TABLE_KEYS.each_pair do |k, v|
      @table[k] = value_as_type(fields[v[:index]], v[:type])
    end
  end

  # @return [String]
  def to_s
    keys_sort_by_index.map { |k| @table[k] }
                      .join(', ')
  end

  # @param [Symbol] key
  # @return [String, Integer, Array<Float, String>]
  def value(key)
    @table[key]
  end

  # @param [Array<Symbol>] cols Column names (symbols) to select
  # @return [Array<String, Integer, Float>]
  def select(cols)
    cols.map do |col|
      value(col).is_a?(Array) ? value(col)[0] : value(col)
    end
  end

  private

  # @return [Array<Symbol>] sorted (order guaranteed) keys
  def keys_sort_by_index
    TABLE_KEYS.keys.sort { |k1, k2| TABLE_KEYS[k1][:index] <=> TABLE_KEYS[k2][:index] }
  end

  # rubocop:disable Style/EmptyElse

  # @param [String] value String value (before convert/normalize)
  # @param [Symbol] type value type
  # @return [String, Integer, Array<Float, String>, nil]
  def value_as_type(value, type)
    case type
    when :string then value
    when :integer then value.to_i
    when :unit_num then unit_num(value)
    else nil # error
    end
  end
  # rubocop:enable Style/EmptyElse

  # @param [String] unit_num_str
  # @return [Array<Float, String>] number and unit
  def unit_num(unit_num_str)
    match = unit_num_str.match(/(?<num_str>[\d.]+)(?<unit_str>[\w%]+)/)
    if match
      # [match[:num_str].to_f, match[:unit_str]] # for debugging (not normalized; pass-through)
      normalize_unit(match[:num_str].to_f, match[:unit_str])
    else
      [nil, nil] # error
    end
  end

  # rubocop:disable Metrics/CyclomaticComplexity

  # @param [Float] num Number (Value)
  # @param [String] unit Unit string
  # @return Array<Float, String>
  def normalize_unit(num, unit)
    case unit
    when 'kB' then [10**3 * num, 'B']
    when 'MB' then [10**6 * num, 'B']
    when 'GB' then [10**9 * num, 'B']
    when 'KiB' then [2**10 * num, 'B']
    when 'MiB' then [2**20 * num, 'B']
    when 'GiB' then [2**30 * num, 'B']
    when 'B', '%' then [num, unit] # nothing to do
    else [nil, nil] # error
    end
  end
  # rubocop:enable Metrics/CyclomaticComplexity
end

# several container status at a time
class TimeDockerStats
  attr_reader :epoch, :elapsed_time
  attr_accessor :stats

  # @param [String, Float] epoch_start Epoch string (start time)
  # @param [String] epoch Epoch string (target time)
  def initialize(epoch_start, epoch)
    @epoch = epoch.to_f
    @elapsed_time = @epoch - epoch_start.to_f
    @stats = [] # -> Array of DockerStat
  end

  # @return [String]
  def to_s
    ([@epoch] + @stats.map(&:to_s)).join(', ')
  end

  # @param [Array<String>] names Container names to select
  # @param [Array<Symbol>] cols Column names (symbols) to select
  # @return [Array<Array>]
  #   [  #        name[0]   name[1]   name[2]...
  #      [epoch, [value[0], value[1], value[2], ...], = col[0]
  #      [epoch, [...                              ], = col[1]
  #      ...
  #   ]
  def select(names, cols)
    # Notice: KEEP order of (container-)names
    stats = names.map { |name| @stats.find { |stat| stat.value(:name) == name } }
                 .map { |stat| stat.select(cols) }
    [@elapsed_time] + stats
  end
end

# all stats data
class DockerStatsLog
  attr_reader :time_stats_list

  # @param [String] log_dir Docker stats directory
  def initialize(log_dir)
    @log_dir = log_dir
    @time_stats_list = [] # Array of TimeDockerStats
    @time_stats_index = {} # index to find time-stats object from time (epoch)
    read_stats
  end

  # @param [String] container Target container name
  def pick_column_of(container, col)
    @time_stats_list.map { |ts| ts.select([container], [col])} # returns [[epoch [col-value]], ...]
                    .map {|d| d[1][0]} # returns [col-value, ...]
  end

  private

  # Read docker stats data (stats.log) in directory
  # @return [void]
  def read_stats
    File.open(File.join(@log_dir, 'stats.log'), 'r') do |file|
      file.each_line do |line|
        line.chomp!

        # header line
        match = line.match(/\[(?<epoch>[\d.]+)\] CONTAINER ID.*$/)
        if match
          start_time = @time_stats_list.empty? ? match[:epoch] : @time_stats_list[0].epoch
          time_stats = TimeDockerStats.new(start_time, match[:epoch])
          @time_stats_list.push(time_stats)
          @time_stats_index[match[:epoch]] = time_stats
          next
        end

        # data line
        match = line.match(/\[(?<epoch>[\d.]+)\] (?<line>.+)$/)
        if match && @time_stats_index.key?(match[:epoch])
          @time_stats_index[match[:epoch]].stats.push(DockerStat.new(match[:line])) unless @time_stats_list.empty?
        else
          warn "Error: Epoch #{match[:epoch]} not found in stats data"
        end
      end
    end
    # risk hedge
    @time_stats_list.sort! { |a, b| a.epoch <=> b.epoch }
  end
end
