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
        attribute(
          router_id: '172.16.0.5' # TODO
         )
        term_point 'peer_172.16.0.6' do
          support %w[layer3 PNI01 Ethernet1]
          attribute(
            local_as: 65_550,
            local_ip: '172.16.0.5',
            remote_as: 65_518,
            remote_ip: '172.16.0.6'
          )
        end
        term_point 'peer_172.16.1.10' do
          support %w[layer3 PNI01 Ethernet2]
          attribute(
            local_as: 65_550,
            local_ip: '172.16.1.9',
            remote_as: 65_518,
            remote_ip: '172.16.1.10'
          )
        end
      end

      # AS65520, POI-East
      node 'POI-East' do # TODO: Hostname must be Router-ID in bgp layer
        support %w[layer3 POI-East]
        attribute(
          router_id: '172.16.0.10' # TODO
        )
        term_point 'peer_192.168.0.9' do
          support %w[layer3 POI-East Ethernet1]
          attribute(
            local_as: 65_520,
            local_ip: '192.168.0.10',
            remote_as: 65_518,
            remote_ip: '192.168.0.9'
          )
        end
        term_point 'peer_192.168.0.13' do
          support %w[layer3 POI-East Ethernet2]
          attribute(
            local_as: 65_520,
            local_ip: '192.168.0.14',
            remote_as: 65_518,
            remote_ip: '192.168.0.13'
          )
        end
      end
    end
  end
end
# rubocop:enable Metrics/MethodLength
