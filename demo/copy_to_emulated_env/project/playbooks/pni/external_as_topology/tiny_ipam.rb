# frozen_string_literal: true

require 'ipaddr'
require 'singleton'

# External-AS IP-Address Management
class TinyIPAM
  attr_reader :link_count, :loopback_count

  include Singleton

  def initialize
    @base_prefix = IPAddr.new('169.254.0.0/16')

    @loopback_count = 0
    @link_count = 0
  end

  # @return [void]
  def reset
    @loopback_count = 0
    @link_count = 0
  end

  # @param [String] prefix_str IPv4 prefix string (e.g. a.b.c.d/xx, /xx >= /16)
  # @return [IPAddr] base prefix
  def assign_base_prefix(prefix_str)
    warn "Warn: assign base prefix: #{prefix_str}"
    reset

    addr_check = IPAddr.new(prefix_str)
    if addr_check.prefix > 23
      # NOTE: The subnet operations possible with IPAddr are limited.
      #   Therefore, operations with addr block bigger than /23 are assumed.
      warn 'Error: base prefix is too small (specify prefix bigger than /23)'
      return @base_prefix # NOP: not changed
    end

    # changed
    @base_prefix = addr_check
  end

  # address block assign
  #    x.x.x.0 (prefix length<24, bigger than /23 block)
  #          0/24 : loopback
  #          1/24 : link
  #           :       : (remaining address blocks are for links)

  # @param [Integer] index Loopback number (n-th loopback, n=0,1,...)
  # @return [IPAddr] loopback ip addr
  # @raise [StandardError] loopback /24 overflow
  def loopback_ip_of_index(index)
    # a.b.0.0/24, 0 <= index <= 255 (per /32 = 1-ip addr index)
    raise StandardError, "Loopback address overflow in #{ip_and_prefix_str(@base_prefix)}" if index >= 256

    mask = ip_mask_str(@base_prefix)
    ip = ((@base_prefix & mask) | "0.0.0.#{index}")
    ip.prefix = 32
    ip
  end

  # rubocop:disable Metrics/AbcSize

  # @param [Integer] index Link number (n-th link, n=0,1,...)
  # @return [IPAddr] link (segment) ip addr
  # @raise [StandardError] link addr block overflow
  def link_ip_of_index(index)
    # a.b.(1...255).x/30, 0 <= index (per /30 = 4-ip-addrs index)
    base_oct3 = @base_prefix.to_s.split('.')[2].to_i
    oct3 = base_oct3 + (index / 64) + 1 # +1 -> next of loopback block: x.x.?.0/24
    if oct3 > (2**(24 - @base_prefix.prefix)) - 1 + base_oct3
      raise StandardError, "Link address overflow in #{ip_and_prefix_str(@base_prefix)}"
    end

    ip = ((@base_prefix & '255.255.0.0') | "0.0.#{oct3}.#{index * 4 % 256}")
    ip.prefix = 30
    ip
  end
  # rubocop:enable Metrics/AbcSize

  # @return [Integer] loopback counter
  def count_loopback
    @loopback_count += 1
  end

  # @return [IPAddr] current loopback ip
  def current_loopback_ip
    loopback_ip_of_index(@loopback_count)
  end

  # @return [String] current loopback ip string (with prefix length, /nn)
  def current_loopback_ip_str
    ip_and_prefix_str(current_loopback_ip)
  end

  # @return [Integer] link counter
  def count_link
    @link_count += 1
  end

  # @return [IPAddr] current link (segment) ip
  def current_link_ip
    link_ip_of_index(@link_count)
  end

  # @return [String] current link ip string (with prefix length, /nn)
  def current_link_ip_str
    ip_and_prefix_str(current_link_ip)
  end

  # @return [Array(IPAddr, IPAddr)] ip addr pair for link edge interface in current link ip (segment)
  def current_link_intf_ip_pair
    ip = current_link_ip
    ip_oct4 = ip.to_s.split('.')[-1].to_i
    [ip_oct4 + 1, ip_oct4 + 2].map { |oct4| (ip & '255.255.255.0') | "0.0.0.#{oct4}" }
  end

  # @return [Array(String, String)] ip addr string pair for link edge
  def current_link_intf_ip_str_pair
    current_link_intf_ip_pair.map { |ip| ip_and_prefix_str(ip) }
  end

  # @param [IPAddr] ip IP addr
  # @return [String] subnet mask
  def ip_mask_str(ip)
    ip.inspect.match(%r{/(.+)>})[1]
  end

  # @param [IPAddr] ip IP addr
  # @return [String] IP addr to string with prefix length
  def ip_and_prefix_str(ip)
    "#{ip}/#{ip.prefix}"
  end
end
