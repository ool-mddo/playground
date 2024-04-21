# frozen_string_literal: true

require 'json'
require 'netomox'

# NOTE: Use `load` to loading local esternal-as scripts
#   without netomox-exp process reloading when updated these scripts.
load "#{__dir__}/bgp_as.rb"
load "#{__dir__}/bgp_proc.rb"
load "#{__dir__}/layer3.rb"

# @param [Hash] opts Options
# @return [Hash] External-AS topology data (rfc8345)
def generate_topology(opts = {})
  warn "loading mddo-bgp/original_asis/external_as_topology/pni_te, #generate_topology with #{opts}"
  nws = Netomox::DSL::Networks.new
  register_bgp_as(nws)
  register_bgp_proc(nws)
  register_layer3(nws)
  nws.topo_data
end

# If this script is executed directly
puts JSON.pretty_generate(generate_topology) if $0 == __FILE__
