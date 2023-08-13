# frozen_string_literal: true

require 'netomox'

# rubocop:disable Metrics/MethodLength
def register_bgp_proc(nws)
  nws.register do
    network 'bgp_proc' do
      type Netomox::NWTYPE_MDDO_BGP_PROC
      support 'layer3'

      # AS65550, PNI
      node 'PNI01' do # TODO: Hostname must be Router-ID in bgp layer
        support %w[layer3 PNI01]
        term_point 'peer_172.16.0.6' do
          support %w[layer3 PNI01 Ethernet1]
        end
        term_point 'peer_172.16.1.10' do
          support %w[layer3 PNI01 Ethernet2]
        end
      end

      # AS65520, POI-East
      node 'POI-East' do
        support %w[layer3 POI-East]
        term_point 'peer_192.168.0.9' do
          support %w[layer3 POI-East Ethernet1]
        end
        term_point 'peer_192.168.0.13' do
          support %w[layer3 POI-East Ethernet2]
        end
      end
    end
  end
end
# rubocop:enable Metrics/MethodLength
