
# frozen_string_literal: true
require 'netomox'

def register_layer3(nws)
  nws.register do
    network 'layer3' do
      type Netomox::NWTYPE_MDDO_L3
      node 'AS65550-1' do
        attribute( node_type: 'node' )
        term_point 'Ethernet1' do
          attribute( ip_addrs: %w[172.16.0.5/30] )
        end
        term_point 'Ethernet2' do
          attribute( ip_addrs: %w[169.254.0.1/30] )
        end
        term_point 'Ethernet3' do
          attribute( ip_addrs: %w[169.254.0.5/30] )
        end
        term_point 'Ethernet4' do
          attribute( ip_addrs: %w[10.0.3.1/24] )
        end
      end
      node 'AS65550-2' do
        attribute( node_type: 'node' )
        term_point 'Ethernet1' do
          attribute( ip_addrs: %w[172.16.1.9/30] )
        end
        term_point 'Ethernet2' do
          attribute( ip_addrs: %w[169.254.0.2/30] )
        end
        term_point 'Ethernet3' do
          attribute( ip_addrs: %w[169.254.0.9/30] )
        end
        term_point 'Ethernet4' do
          attribute( ip_addrs: %w[10.0.2.1/24] )
        end
        term_point 'Ethernet5' do
          attribute( ip_addrs: %w[10.0.4.1/24] )
        end
        term_point 'Ethernet6' do
          attribute( ip_addrs: %w[10.0.1.1/24] )
        end
      end
      bdlink %w[AS65550ADD Ethernet1 edge-tk03 GigabitEthernet0/0/0/2]
      node 'AS65550ADD' do
        attribute( node_type: 'node' )
        term_point 'Ethernet1' do
          attribute( ip_addrs: %w[172.16.1.17/30] )
        end
        term_point 'Ethernet2' do
          attribute( ip_addrs: %w[169.254.0.6/30] )
        end
        term_point 'Ethernet3' do
          attribute( ip_addrs: %w[169.254.0.10/30] )
        end
      end
      node 'AS65520-1' do
        attribute( node_type: 'node' )
        term_point 'Ethernet1' do
          attribute( ip_addrs: %w[192.168.0.10/30] )
        end
        term_point 'Ethernet2' do
          attribute( ip_addrs: %w[169.254.0.13/30] )
        end
        term_point 'Ethernet3' do
          attribute( ip_addrs: %w[10.120.0.1/24] )
        end
        term_point 'Ethernet4' do
          attribute( ip_addrs: %w[10.130.0.1/24] )
        end
      end
      node 'AS65520-3' do
        attribute( node_type: 'node' )
        term_point 'Ethernet1' do
          attribute( ip_addrs: %w[192.168.0.18/30] )
        end
        term_point 'Ethernet2' do
          attribute( ip_addrs: %w[169.254.0.14/30] )
        end
        term_point 'Ethernet3' do
          attribute( ip_addrs: %w[10.110.0.1/24] )
        end
        term_point 'Ethernet4' do
          attribute( ip_addrs: %w[10.100.0.1/24] )
        end
      end
      node 'Seg_169.254.0.0/30' do
        attribute( node_type: 'segment', prefixes: [{ prefix: '169.254.0.0/30', metric: 0 }] )
        term_point 'AS65550-1_Ethernet2'
        term_point 'AS65550-2_Ethernet2'
      end
      bdlink %w[AS65550-1 Ethernet2 Seg_169.254.0.0/30 AS65550-1_Ethernet2]
      bdlink %w[AS65550-2 Ethernet2 Seg_169.254.0.0/30 AS65550-2_Ethernet2]
      node 'Seg_169.254.0.4/30' do
        attribute( node_type: 'segment', prefixes: [{ prefix: '169.254.0.4/30', metric: 0 }] )
        term_point 'AS65550-1_Ethernet3'
        term_point 'AS65550ADD_Ethernet2'
      end
      bdlink %w[AS65550-1 Ethernet3 Seg_169.254.0.4/30 AS65550-1_Ethernet3]
      bdlink %w[AS65550ADD Ethernet2 Seg_169.254.0.4/30 AS65550ADD_Ethernet2]
      node 'Seg_169.254.0.8/30' do
        attribute( node_type: 'segment', prefixes: [{ prefix: '169.254.0.8/30', metric: 0 }] )
        term_point 'AS65550-2_Ethernet3'
        term_point 'AS65550ADD_Ethernet3'
      end
      bdlink %w[AS65550-2 Ethernet3 Seg_169.254.0.8/30 AS65550-2_Ethernet3]
      bdlink %w[AS65550ADD Ethernet3 Seg_169.254.0.8/30 AS65550ADD_Ethernet3]
      node 'Seg_169.254.0.12/30' do
        attribute( node_type: 'segment', prefixes: [{ prefix: '169.254.0.12/30', metric: 0 }] )
        term_point 'AS65520-1_Ethernet2'
        term_point 'AS65520-3_Ethernet2'
      end
      bdlink %w[AS65520-1 Ethernet2 Seg_169.254.0.12/30 AS65520-1_Ethernet2]
      bdlink %w[AS65520-3 Ethernet2 Seg_169.254.0.12/30 AS65520-3_Ethernet2]
      node 'Seg_10.0.2.0/24' do
        attribute( node_type: 'segment', prefixes: [{ prefix: '10.0.2.0/24', metric: 0 }] )
        term_point 'AS65550-2_Ethernet4'
        term_point 'endpoint01-iperf0_Ethernet1'
      end
      bdlink %w[AS65550-2 Ethernet4 Seg_10.0.2.0/24 AS65550-2_Ethernet4]
      bdlink %w[endpoint01-iperf0 Ethernet1 Seg_10.0.2.0/24 endpoint01-iperf0_Ethernet1]
      node 'endpoint01-iperf0' do
        attribute(
          node_type: 'endpoint',
          static_routes: [{ prefix: '0.0.0.0/0', next_hop: '10.0.2.1', description: 'default' }]
        )
        term_point 'Ethernet1' do
          attribute({ ip_addrs: %w[10.0.2.100/24] })
        end
      end
      node 'Seg_10.0.4.0/24' do
        attribute( node_type: 'segment', prefixes: [{ prefix: '10.0.4.0/24', metric: 0 }] )
        term_point 'AS65550-2_Ethernet5'
        term_point 'endpoint01-iperf1_Ethernet1'
      end
      bdlink %w[AS65550-2 Ethernet5 Seg_10.0.4.0/24 AS65550-2_Ethernet5]
      bdlink %w[endpoint01-iperf1 Ethernet1 Seg_10.0.4.0/24 endpoint01-iperf1_Ethernet1]
      node 'endpoint01-iperf1' do
        attribute(
          node_type: 'endpoint',
          static_routes: [{ prefix: '0.0.0.0/0', next_hop: '10.0.4.1', description: 'default' }]
        )
        term_point 'Ethernet1' do
          attribute({ ip_addrs: %w[10.0.4.100/24] })
        end
      end
      node 'Seg_10.0.1.0/24' do
        attribute( node_type: 'segment', prefixes: [{ prefix: '10.0.1.0/24', metric: 0 }] )
        term_point 'AS65550-2_Ethernet6'
        term_point 'endpoint01-iperf2_Ethernet1'
      end
      bdlink %w[AS65550-2 Ethernet6 Seg_10.0.1.0/24 AS65550-2_Ethernet6]
      bdlink %w[endpoint01-iperf2 Ethernet1 Seg_10.0.1.0/24 endpoint01-iperf2_Ethernet1]
      node 'endpoint01-iperf2' do
        attribute(
          node_type: 'endpoint',
          static_routes: [{ prefix: '0.0.0.0/0', next_hop: '10.0.1.1', description: 'default' }]
        )
        term_point 'Ethernet1' do
          attribute({ ip_addrs: %w[10.0.1.100/24] })
        end
      end
      node 'Seg_10.0.3.0/24' do
        attribute( node_type: 'segment', prefixes: [{ prefix: '10.0.3.0/24', metric: 0 }] )
        term_point 'AS65550-1_Ethernet4'
        term_point 'endpoint01-iperf3_Ethernet1'
      end
      bdlink %w[AS65550-1 Ethernet4 Seg_10.0.3.0/24 AS65550-1_Ethernet4]
      bdlink %w[endpoint01-iperf3 Ethernet1 Seg_10.0.3.0/24 endpoint01-iperf3_Ethernet1]
      node 'endpoint01-iperf3' do
        attribute(
          node_type: 'endpoint',
          static_routes: [{ prefix: '0.0.0.0/0', next_hop: '10.0.3.1', description: 'default' }]
        )
        term_point 'Ethernet1' do
          attribute({ ip_addrs: %w[10.0.3.100/24] })
        end
      end
      node 'Seg_10.110.0.0/24' do
        attribute( node_type: 'segment', prefixes: [{ prefix: '10.110.0.0/24', metric: 0 }] )
        term_point 'AS65520-3_Ethernet3'
        term_point 'endpoint02-iperf0_Ethernet1'
      end
      bdlink %w[AS65520-3 Ethernet3 Seg_10.110.0.0/24 AS65520-3_Ethernet3]
      bdlink %w[endpoint02-iperf0 Ethernet1 Seg_10.110.0.0/24 endpoint02-iperf0_Ethernet1]
      node 'endpoint02-iperf0' do
        attribute(
          node_type: 'endpoint',
          static_routes: [{ prefix: '0.0.0.0/0', next_hop: '10.110.0.1', description: 'default' }]
        )
        term_point 'Ethernet1' do
          attribute({ ip_addrs: %w[10.110.0.100/24] })
        end
      end
      node 'Seg_10.100.0.0/24' do
        attribute( node_type: 'segment', prefixes: [{ prefix: '10.100.0.0/24', metric: 0 }] )
        term_point 'AS65520-3_Ethernet4'
        term_point 'endpoint02-iperf1_Ethernet1'
      end
      bdlink %w[AS65520-3 Ethernet4 Seg_10.100.0.0/24 AS65520-3_Ethernet4]
      bdlink %w[endpoint02-iperf1 Ethernet1 Seg_10.100.0.0/24 endpoint02-iperf1_Ethernet1]
      node 'endpoint02-iperf1' do
        attribute(
          node_type: 'endpoint',
          static_routes: [{ prefix: '0.0.0.0/0', next_hop: '10.100.0.1', description: 'default' }]
        )
        term_point 'Ethernet1' do
          attribute({ ip_addrs: %w[10.100.0.100/24] })
        end
      end
      node 'Seg_10.120.0.0/24' do
        attribute( node_type: 'segment', prefixes: [{ prefix: '10.120.0.0/24', metric: 0 }] )
        term_point 'AS65520-1_Ethernet3'
        term_point 'endpoint02-iperf2_Ethernet1'
      end
      bdlink %w[AS65520-1 Ethernet3 Seg_10.120.0.0/24 AS65520-1_Ethernet3]
      bdlink %w[endpoint02-iperf2 Ethernet1 Seg_10.120.0.0/24 endpoint02-iperf2_Ethernet1]
      node 'endpoint02-iperf2' do
        attribute(
          node_type: 'endpoint',
          static_routes: [{ prefix: '0.0.0.0/0', next_hop: '10.120.0.1', description: 'default' }]
        )
        term_point 'Ethernet1' do
          attribute({ ip_addrs: %w[10.120.0.100/24] })
        end
      end
      node 'Seg_10.130.0.0/24' do
        attribute( node_type: 'segment', prefixes: [{ prefix: '10.130.0.0/24', metric: 0 }] )
        term_point 'AS65520-1_Ethernet4'
        term_point 'endpoint02-iperf3_Ethernet1'
      end
      bdlink %w[AS65520-1 Ethernet4 Seg_10.130.0.0/24 AS65520-1_Ethernet4]
      bdlink %w[endpoint02-iperf3 Ethernet1 Seg_10.130.0.0/24 endpoint02-iperf3_Ethernet1]
      node 'endpoint02-iperf3' do
        attribute(
          node_type: 'endpoint',
          static_routes: [{ prefix: '0.0.0.0/0', next_hop: '10.130.0.1', description: 'default' }]
        )
        term_point 'Ethernet1' do
          attribute({ ip_addrs: %w[10.130.0.100/24] })
        end
      end
    end
  end
end