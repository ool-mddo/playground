# frozen_string_literal: true

require 'ipaddr'
require 'singleton'

# External-AS IP-address Management
class IPManagement
  attr_reader :link_count, :loopback_count

  include Singleton

  def initialize
    @base_prefix = IPAddr.new('169.254.0.0/16')

    @loopback_count = 0
    @link_count = 0
  end

  # @param [String] prefix_str IPv4 prefix string (e.g. a.b.c.d/xx, /xx >= /16)
  # @return [IPAddr] base prefix
  def assign_base_prefix(prefix_str)
    warn "Warn: assign base prefix: #{prefix_str}"
    addr_check = IPAddr.new(prefix_str)
    if addr_check.prefix < 16
      warn 'Error: base prefix is too small (specify prefix > /16)'
      return @base_prefix # NOP: not changed
    end

    # changed
    @base_prefix = addr_check
  end

  def loopback_ip_with_index(index)
    # a.b.0.0/24, 0 <= index <= 255 (per /32 = 1-ip addr index)
    ip = ((@base_prefix & '255.255.0.0') | "0.0.0.#{index}")
    ip.prefix = 32
    ip
  end

  def link_ip_with_index(index)
    # a.b.(1...255).x/30, 0 <= index <= 64*255 = 16320 (per /30 = 4-ip-addrs index)
    ip = ((@base_prefix & '255.255.0.0') | "0.0.#{(index / 64) + 1}.#{index * 4 % 256}")
    ip.prefix = 30
    ip
  end

  def count_loopback
    @loopback_count += 1
  end

  def current_loopback_ip
    loopback_ip_with_index(@loopback_count)
  end

  def current_loopback_ip_str
    ip_and_prefix_str(current_loopback_ip)
  end

  def count_link
    @link_count += 1
  end

  def current_link_ip
    link_ip_with_index(@link_count)
  end

  def current_link_ip_str
    ip_and_prefix_str(current_link_ip)
  end

  def current_link_intf_ip_pair
    ip = current_link_ip
    ip_oct4 = ip.to_s.split('.')[-1].to_i
    [ip_oct4 + 1, ip_oct4 + 2].map { |oct4| (ip & '255.255.255.0') | "0.0.0.#{oct4}" }
  end

  def current_link_intf_ip_str_pair
    current_link_intf_ip_pair.map { |ip| ip_and_prefix_str(ip) }
  end

  def ip_and_prefix_str(ip)
    "#{ip}/#{ip.prefix}"
  end
end
