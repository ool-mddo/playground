
# frozen_string_literal: true
def register_bgp_as(nws)
  nws.register do
    network 'bgp_as' do
      type Netomox::NWTYPE_MDDO_BGP_AS
      support 'bgp_proc'

      # self
      node 'as65518' do
        attribute({ as_number: 65_518 })
        # supporting nodes and term-points will be generated from original-asis configs
        term_point 'peer_172.16.0.5' do
          attribute({ description: 'from TBD to TBD' })
          support %w[bgp_proc 192.168.255.5 peer_172.16.0.5 ]
        end
        term_point 'peer_192.168.0.10' do
          attribute({ description: 'from TBD to TBD' })
          support %w[bgp_proc 192.168.255.5 peer_192.168.0.10 ]
        end
        term_point 'peer_172.16.1.9' do
          attribute({ description: 'from TBD to TBD' })
          support %w[bgp_proc 192.168.255.6 peer_172.16.1.9 ]
        end
        term_point 'peer_192.168.0.14' do
          attribute({ description: 'from TBD to TBD' })
          support %w[bgp_proc 192.168.255.6 peer_192.168.0.14 ]
        end
        term_point 'peer_172.16.1.17' do
          attribute({ description: 'from TBD to TBD' })
          support %w[bgp_proc 192.168.255.7 peer_172.16.1.17 ]
        end
        term_point 'peer_192.168.0.18' do
          attribute({ description: 'from TBD to TBD' })
          support %w[bgp_proc 192.168.255.7 peer_192.168.0.18 ]
        end
      end
      node 'as65550' do
        attribute({ as_number: 65_550 })
        support %w[bgp_proc AS65550-1]
        term_point 'peer_172.16.0.6' do
          attribute({ description: 'from TBD to TBD' })
          support %w[bgp_proc AS65550-1 peer_172.16.0.6 ]
        end
        support %w[bgp_proc AS65550-1]
        term_point 'peer_172.16.1.18' do
          attribute({ description: 'from TBD to TBD' })
          support %w[bgp_proc AS65550-1 peer_172.16.1.18 ]
        end
        support %w[bgp_proc AS65550-2]
        term_point 'peer_172.16.1.10' do
          attribute({ description: 'from TBD to TBD' })
          support %w[bgp_proc AS65550-2 peer_172.16.1.10 ]
        end
      end
      node 'as65520' do
        attribute({ as_number: 65_520 })
        support %w[bgp_proc AS65520-1]
        term_point 'peer_192.168.0.9' do
          attribute({ description: 'from TBD to TBD' })
          support %w[bgp_proc AS65520-1 peer_192.168.0.9 ]
        end
        support %w[bgp_proc AS65520-2]
        term_point 'peer_192.168.0.13' do
          attribute({ description: 'from TBD to TBD' })
          support %w[bgp_proc AS65520-2 peer_192.168.0.13 ]
        end
        support %w[bgp_proc AS65520-3]
        term_point 'peer_192.168.0.17' do
          attribute({ description: 'from TBD to TBD' })
          support %w[bgp_proc AS65520-3 peer_192.168.0.17 ]
        end
      end
      # inter AS links
      bdlink %w[as65518 peer_172.16.0.5 as65550 peer_172.16.0.6]
      bdlink %w[as65518 peer_172.16.1.17 as65550 peer_172.16.1.18]
      bdlink %w[as65518 peer_172.16.1.9 as65550 peer_172.16.1.10]
      bdlink %w[as65518 peer_192.168.0.10 as65520 peer_192.168.0.9]
      bdlink %w[as65518 peer_192.168.0.14 as65520 peer_192.168.0.13]
      bdlink %w[as65518 peer_192.168.0.18 as65520 peer_192.168.0.17]
    end
  end
end