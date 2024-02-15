
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
            local_as: 65_550,
            local_ip: '172.16.0.5',
            remote_as: 65_518,
            remote_ip: '172.16.0.6'
          )
        end
        term_point 'peer_100.0.0.2' do
          support %w[layer3 AS65550-1  Ethernet2]
          attribute(
            local_as: 65_550,
            local_ip: '100.0.0.1',
            remote_as: 65_550,
            remote_ip: '100.0.0.2'
          )
        end
        term_point 'peer_100.0.0.6' do
          support %w[layer3 AS65550-1  Ethernet3]
          attribute(
            local_as: 65_550,
            local_ip: '100.0.0.5',
            remote_as: 65_550,
            remote_ip: '100.0.0.6'
          )
        end
      end
      bdlink %w[AS65550-1 peer_100.0.0.2 AS65550-2 peer_100.0.0.1]
      bdlink %w[AS65550-1 peer_100.0.0.6 AS65550-3 peer_100.0.0.5]
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
        term_point 'peer_100.0.0.1' do
          support %w[layer3 AS65550-2  Ethernet2]
          attribute(
            local_as: 65_550,
            local_ip: '100.0.0.2',
            remote_as: 65_550,
            remote_ip: '100.0.0.1'
          )
        end
        term_point 'peer_100.0.0.10' do
          support %w[layer3 AS65550-2  Ethernet3]
          attribute(
            local_as: 65_550,
            local_ip: '100.0.0.9',
            remote_as: 65_550,
            remote_ip: '100.0.0.10'
          )
        end
      end
      bdlink %w[AS65550-2 peer_100.0.0.10 AS65550-3 peer_100.0.0.9]
      node 'AS65550-3' do
        support %w[layer3 AS65550-3]
        attribute(
          flags: %w[ext-bgp-speaker],
          router_id: '0.0.0.3' # TODO
        )
        term_point 'peer_172.16.1.18' do
          support %w[layer3 AS65550-3  Ethernet1]
          attribute(
            local_as: 65_550,
            local_ip: '172.16.1.17',
            remote_as: 65_518,
            remote_ip: '172.16.1.18'
          )
        end
        term_point 'peer_100.0.0.5' do
          support %w[layer3 AS65550-3  Ethernet2]
          attribute(
            local_as: 65_550,
            local_ip: '100.0.0.6',
            remote_as: 65_550,
            remote_ip: '100.0.0.5'
          )
        end
        term_point 'peer_100.0.0.9' do
          support %w[layer3 AS65550-3  Ethernet3]
          attribute(
            local_as: 65_550,
            local_ip: '100.0.0.10',
            remote_as: 65_550,
            remote_ip: '100.0.0.9'
          )
        end
      end
      node 'AS65520-1' do
        support %w[layer3 AS65520-1]
        attribute(
          flags: %w[ext-bgp-speaker],
          router_id: '0.0.0.4' # TODO
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
        term_point 'peer_100.0.0.14' do
          support %w[layer3 AS65520-1  Ethernet2]
          attribute(
            local_as: 65_520,
            local_ip: '100.0.0.13',
            remote_as: 65_520,
            remote_ip: '100.0.0.14'
          )
        end
        term_point 'peer_100.0.0.18' do
          support %w[layer3 AS65520-1  Ethernet3]
          attribute(
            local_as: 65_520,
            local_ip: '100.0.0.17',
            remote_as: 65_520,
            remote_ip: '100.0.0.18'
          )
        end
      end
      bdlink %w[AS65520-1 peer_100.0.0.14 AS65520-2 peer_100.0.0.13]
      bdlink %w[AS65520-1 peer_100.0.0.18 AS65520-3 peer_100.0.0.17]
      node 'AS65520-2' do
        support %w[layer3 AS65520-2]
        attribute(
          flags: %w[ext-bgp-speaker],
          router_id: '0.0.0.5' # TODO
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
        term_point 'peer_100.0.0.13' do
          support %w[layer3 AS65520-2  Ethernet2]
          attribute(
            local_as: 65_520,
            local_ip: '100.0.0.14',
            remote_as: 65_520,
            remote_ip: '100.0.0.13'
          )
        end
        term_point 'peer_100.0.0.22' do
          support %w[layer3 AS65520-2  Ethernet3]
          attribute(
            local_as: 65_520,
            local_ip: '100.0.0.21',
            remote_as: 65_520,
            remote_ip: '100.0.0.22'
          )
        end
      end
      bdlink %w[AS65520-2 peer_100.0.0.22 AS65520-3 peer_100.0.0.21]
      node 'AS65520-3' do
        support %w[layer3 AS65520-3]
        attribute(
          flags: %w[ext-bgp-speaker],
          router_id: '0.0.0.6' # TODO
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
        term_point 'peer_100.0.0.17' do
          support %w[layer3 AS65520-3  Ethernet2]
          attribute(
            local_as: 65_520,
            local_ip: '100.0.0.18',
            remote_as: 65_520,
            remote_ip: '100.0.0.17'
          )
        end
        term_point 'peer_100.0.0.21' do
          support %w[layer3 AS65520-3  Ethernet3]
          attribute(
            local_as: 65_520,
            local_ip: '100.0.0.22',
            remote_as: 65_520,
            remote_ip: '100.0.0.21'
          )
        end
      end
    end
  end
end