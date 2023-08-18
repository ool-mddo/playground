# frozen_string_literal: true

require 'netomox'

# rubocop:disable Metrics/MethodLength, Metrics/BlockLength, Metrics/AbcSize
def register_layer3(nws)
  nws.register do
    network 'layer3' do
      type Netomox::NWTYPE_MDDO_L3

      # AS65550, PNI
      node 'PNI01' do
        # to bgp router
        attribute({ node_type: 'node' })
        term_point 'Ethernet1' do
          attribute({ ip_addrs: %w[172.16.0.5/30] })
        end
        term_point 'Ethernet2' do
          attribute({ ip_addrs: %w[172.16.1.9/30] })
        end

        # to host
        term_point 'Ethernet3' do
          attribute({ ip_addrs: %w[10.0.1.1/24] })
        end
        term_point 'Ethernet4' do
          attribute({ ip_addrs: %w[10.0.2.1/24] })
        end
        term_point 'Ethernet5' do
          attribute({ ip_addrs: %w[10.0.3.1/24] })
        end
        term_point 'Ethernet6' do
          attribute({ ip_addrs: %w[10.0.4.1/24] })
        end
      end

      node 'Seg_10.0.1.0/24' do
        attribute({ node_type: 'segment', prefixes: [{ prefix: '10.0.1.0/24', metric: 0 }] })
        term_point 'PNI01_Ethernet3'
        term_point 'endpoint01-iperf1_ens2'
      end
      node 'Seg_10.0.2.0/24' do
        attribute({ node_type: 'segment', prefixes: [{ prefix: '10.0.2.0/24', metric: 0 }] })
        term_point 'PNI01_Ethernet4'
        term_point 'endpoint01-iperf2_ens3'
      end
      node 'Seg_10.0.3.0/24' do
        attribute({ node_type: 'segment', prefixes: [{ prefix: '10.0.3.0/24', metric: 0 }] })
        term_point 'PNI01_Ethernet5'
        term_point 'endpoint01-iperf3_enp1s4'
      end
      node 'Seg_10.0.4.0/24' do
        attribute({ node_type: 'segment', prefixes: [{ prefix: '10.0.4.0/24', metric: 0 }] })
        term_point 'PNI01_Ethernet6'
        term_point 'endpoint01-iperf4_enp1s5'
      end

      node 'endpoint01-iperf1' do
        attribute({ node_type: 'endpoint' })
        term_point 'ens2' do
          attribute({ ip_addrs: %w[10.0.1.100/24] })
        end
      end
      node 'endpoint01-iperf2' do
        attribute({ node_type: 'endpoint' })
        term_point 'ens3' do
          attribute({ ip_addrs: %w[10.0.2.100/24] })
        end
      end
      node 'endpoint01-iperf3' do
        attribute({ node_type: 'endpoint' })
        term_point 'enp1s4' do
          attribute({ ip_addrs: %w[10.0.3.100/24] })
        end
      end
      node 'endpoint01-iperf4' do
        attribute({ node_type: 'endpoint' })
        term_point 'enp1s5' do
          attribute({ ip_addrs: %w[10.0.4.100/24] })
        end
      end

      bdlink %w[PNI01 Ethernet3 Seg_10.0.1.0/24 PNI01_Ethernet3]
      bdlink %w[PNI01 Ethernet4 Seg_10.0.2.0/24 PNI01_Ethernet4]
      bdlink %w[PNI01 Ethernet5 Seg_10.0.3.0/24 PNI01_Ethernet5]
      bdlink %w[PNI01 Ethernet6 Seg_10.0.4.0/24 PNI01_Ethernet6]

      bdlink %w[Seg_10.0.1.0/24 endpoint01-iperf1_ens2 endpoint01-iperf1 ens2]
      bdlink %w[Seg_10.0.2.0/24 endpoint01-iperf2_ens3 endpoint01-iperf2 ens3]
      bdlink %w[Seg_10.0.3.0/24 endpoint01-iperf3_enp1s4 endpoint01-iperf3 enp1s4]
      bdlink %w[Seg_10.0.4.0/24 endpoint01-iperf4_enp1s5 endpoint01-iperf4 enp1s5]

      # AS65520, POI-East
      node 'POI-East' do
        # to bgp router
        attribute({ node_type: 'node' })
        term_point 'Ethernet1' do
          attribute({ ip_addrs: %w[192.168.0.10/30] })
        end
        term_point 'Ethernet2' do
          attribute({ ip_addrs: %w[192.168.0.14/30] })
        end

        # to host
        term_point 'Ethernet3' do
          attribute({ ip_addrs: %w[10.100.0.1/24] })
        end
        term_point 'Ethernet4' do
          attribute({ ip_addrs: %w[10.110.0.1/24] })
        end
        term_point 'Ethernet5' do
          attribute({ ip_addrs: %w[10.120.0.1/24] })
        end
        term_point 'Ethernet6' do
          attribute({ ip_addrs: %w[10.130.0.1/24] })
        end
      end

      node 'Seg_10.100.0.0/16' do
        attribute({ node_type: 'segment', prefixes: [{ prefix: '10.100.0.0/16', metric: 0 }] })
        term_point 'POI-East_Ethernet3'
        term_point 'endpoint02-iperf1_ens2'
      end
      node 'Seg_10.110.0.0/20' do
        attribute({ node_type: 'segment', prefixes: [{ prefix: '10.110.0.0/20', metric: 0 }] })
        term_point 'POI-East_Ethernet4'
        term_point 'endpoint02-iperf2_ens3'
      end
      node 'Seg_10.120.0.0/17' do
        attribute({ node_type: 'segment', prefixes: [{ prefix: '10.120.0.0/17', metric: 0 }] })
        term_point 'POI-East_Ethernet5'
        term_point 'endpoint02-iperf3_enp1s4'
      end
      node 'Seg_10.130.0.0/21' do
        attribute({ node_type: 'segment', prefixes: [{ prefix: '10.130.0.0/21', metric: 0 }] })
        term_point 'POI-East_Ethernet6'
        term_point 'endpoint02-iperf4_enp1s5'
      end

      node 'endpoint02-iperf1' do
        attribute({ node_type: 'endpoint' })
        term_point 'ens2' do
          attribute({ ip_addrs: %w[10.100.0.100/16] })
        end
      end
      node 'endpoint02-iperf2' do
        attribute({ node_type: 'endpoint' })
        term_point 'ens3' do
          attribute({ ip_addrs: %w[10.110.0.100/20] })
        end
      end
      node 'endpoint02-iperf3' do
        attribute({ node_type: 'endpoint' })
        term_point 'enp1s4' do
          attribute({ ip_addrs: %w[10.120.0.100/17] })
        end
      end
      node 'endpoint02-iperf4' do
        attribute({ node_type: 'endpoint' })
        term_point 'enp1s5' do
          attribute({ ip_addrs: %w[10.130.0.100/21] })
        end
      end

      bdlink %w[POI-East Ethernet3 Seg_10.100.0.0/16 POI-East_Ethernet3]
      bdlink %w[POI-East Ethernet4 Seg_10.110.0.0/20 POI-East_Ethernet4]
      bdlink %w[POI-East Ethernet5 Seg_10.120.0.0/17 POI-East_Ethernet5]
      bdlink %w[POI-East Ethernet6 Seg_10.130.0.0/21 POI-East_Ethernet6]

      bdlink %w[Seg_10.100.0.0/16 endpoint02-iperf1_ens2 endpoint02-iperf1 ens2]
      bdlink %w[Seg_10.110.0.0/20 endpoint02-iperf2_ens3 endpoint02-iperf2 ens3]
      bdlink %w[Seg_10.120.0.0/17 endpoint02-iperf3_enp1s4 endpoint02-iperf3 enp1s4]
      bdlink %w[Seg_10.130.0.0/21 endpoint02-iperf4_enp1s5 endpoint02-iperf4 enp1s5]
    end
  end
end
# rubocop:enable Metrics/MethodLength, Metrics/BlockLength, Metrics/AbcSize
