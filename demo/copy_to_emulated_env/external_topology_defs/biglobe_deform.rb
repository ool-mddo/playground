# frozen_string_literal: true

require 'json'
require 'netomox'
require_relative 'biglobe_deform/bgp_as'
require_relative 'biglobe_deform/bgp_proc'
require_relative 'biglobe_deform/layer3'

nws = Netomox::DSL::Networks.new

register_bgp_as(nws)
register_bgp_proc(nws)
register_layer3(nws)

puts JSON.pretty_generate(nws.topo_data)
