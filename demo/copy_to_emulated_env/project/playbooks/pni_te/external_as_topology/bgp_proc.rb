
# frozen_string_literal: true
require 'netomox'

def register_bgp_proc(nws)
  nws.register do
    network 'bgp_proc' do
      type Netomox::NWTYPE_MDDO_BGP_PROC
      support 'layer3'
      node 'AS65550-1' do
        support %w[layer3 AS65550-1]
        attribute(
          flags: %w[ext-bgp-speaker],
          router_id: '0.0.0.1' # TODO
        )
        term_point 'peer_172.16.0.6' do
          support %w[layer3 AS65550-1  Ethernet1]
          attribute(
            flags: %w[ext-bgp-speaker-preferred],
            local_as: 65_550,
            local_ip: '172.16.0.5',
            remote_as: 65_518,
            remote_ip: '172.16.0.6'
          )
        end
        term_point 'peer_172.16.1.18' do
          support %w[layer3 AS65550-1  Ethernet2]
          attribute(
            local_as: 65_550,
            local_ip: '172.16.1.17',
            remote_as: 65_518,
            remote_ip: '172.16.1.18'
          )
        end
        term_point 'peer_169.254.0.2' do
          support %w[layer3 AS65550-1  Ethernet3]
          attribute(
            local_as: 65_550,
            local_ip: '169.254.0.1',
            remote_as: 65_550,
            remote_ip: '169.254.0.2'
          )
        end
      end
      bdlink %w[AS65550-1 peer_169.254.0.2 AS65550-2 peer_169.254.0.1]
      node 'AS65550-2' do
        support %w[layer3 AS65550-2]
        attribute(
          flags: %w[ext-bgp-speaker],
          router_id: '0.0.0.2' # TODO
        )
        term_point 'peer_172.16.1.10' do
          support %w[layer3 AS65550-2  Ethernet1]
          attribute(
            local_as: 65_550,
            local_ip: '172.16.1.9',
            remote_as: 65_518,
            remote_ip: '172.16.1.10'
          )
        end
        term_point 'peer_169.254.0.1' do
          support %w[layer3 AS65550-2  Ethernet2]
          attribute(
            local_as: 65_550,
            local_ip: '169.254.0.2',
            remote_as: 65_550,
            remote_ip: '169.254.0.1'
          )
        end
      end
      node 'AS65520-1' do
        support %w[layer3 AS65520-1]
        attribute(
          flags: %w[ext-bgp-speaker],
          router_id: '0.0.0.3' # TODO
        )
        term_point 'peer_192.168.0.9' do
          support %w[layer3 AS65520-1  Ethernet1]
          attribute(
            local_as: 65_520,
            local_ip: '192.168.0.10',
            remote_as: 65_518,
            remote_ip: '192.168.0.9'
          )
        end
        term_point 'peer_169.254.0.6' do
          support %w[layer3 AS65520-1  Ethernet2]
          attribute(
            local_as: 65_520,
            local_ip: '169.254.0.5',
            remote_as: 65_520,
            remote_ip: '169.254.0.6'
          )
        end
        term_point 'peer_169.254.0.10' do
          support %w[layer3 AS65520-1  Ethernet3]
          attribute(
            local_as: 65_520,
            local_ip: '169.254.0.9',
            remote_as: 65_520,
            remote_ip: '169.254.0.10'
          )
        end
      end
      bdlink %w[AS65520-1 peer_169.254.0.6 AS65520-2 peer_169.254.0.5]
      bdlink %w[AS65520-1 peer_169.254.0.10 AS65520-3 peer_169.254.0.9]
      node 'AS65520-2' do
        support %w[layer3 AS65520-2]
        attribute(
          flags: %w[ext-bgp-speaker],
          router_id: '0.0.0.4' # TODO
        )
        term_point 'peer_192.168.0.13' do
          support %w[layer3 AS65520-2  Ethernet1]
          attribute(
            local_as: 65_520,
            local_ip: '192.168.0.14',
            remote_as: 65_518,
            remote_ip: '192.168.0.13'
          )
        end
        term_point 'peer_169.254.0.5' do
          support %w[layer3 AS65520-2  Ethernet2]
          attribute(
            local_as: 65_520,
            local_ip: '169.254.0.6',
            remote_as: 65_520,
            remote_ip: '169.254.0.5'
          )
        end
        term_point 'peer_169.254.0.14' do
          support %w[layer3 AS65520-2  Ethernet3]
          attribute(
            local_as: 65_520,
            local_ip: '169.254.0.13',
            remote_as: 65_520,
            remote_ip: '169.254.0.14'
          )
        end
      end
      bdlink %w[AS65520-2 peer_169.254.0.14 AS65520-3 peer_169.254.0.13]
      node 'AS65520-3' do
        support %w[layer3 AS65520-3]
        attribute(
          flags: %w[ext-bgp-speaker],
          router_id: '0.0.0.5' # TODO
        )
        term_point 'peer_192.168.0.17' do
          support %w[layer3 AS65520-3  Ethernet1]
          attribute(
            local_as: 65_520,
            local_ip: '192.168.0.18',
            remote_as: 65_518,
            remote_ip: '192.168.0.17'
          )
        end
        term_point 'peer_169.254.0.9' do
          support %w[layer3 AS65520-3  Ethernet2]
          attribute(
            local_as: 65_520,
            local_ip: '169.254.0.10',
            remote_as: 65_520,
            remote_ip: '169.254.0.9'
          )
        end
        term_point 'peer_169.254.0.13' do
          support %w[layer3 AS65520-3  Ethernet3]
          attribute(
            local_as: 65_520,
            local_ip: '169.254.0.14',
            remote_as: 65_520,
            remote_ip: '169.254.0.13'
          )
        end
      end
    end
  end
end