# frozen_string_literal: true

require 'netomox'

# rubocop:disable Metrics/MethodLength, Metrics/BlockLength, Metrics/AbcSize
def register_bgp_as(nws)
  nws.register do
    network 'bgp_as' do
      type Netomox::NWTYPE_MDDO_L3 # temporary
      support 'bgp_proc'
      # attribute({})

      # self
      node 'as65518' do
        # supporting nodes and term-points will be generated from original-asis configs
        term_point 'peer_172.16.0.5' do
          attribute({ description: 'from Edge-TK01 to PNI01' })
          support %w[bgp_proc 192.168.255.5 peer_172.16.0.5]
        end
        term_point 'peer_172.16.1.9' do
          attribute({ description: 'from Edge-TK02 to PNI01' })
          support %w[bgp_proc 192.168.255.6 peer_172.16.1.9]
        end
        term_point 'peer_192.168.0.10' do
          attribute({ description: 'from Edge-TK01 to POI-East' })
          support %w[bgp_proc 192.168.255.5 peer_192.168.0.10]
        end
        term_point 'peer_192.168.0.14' do
          attribute({ description: 'from Edge-TK02 to POI-East' })
          support %w[bgp_proc 192.168.255.6 peer_192.168.0.14]
        end
      end

      # PNI
      node 'as65550' do
        support %w[bgp_proc PNI01]

        term_point 'peer_172.16.0.6' do
          attribute({ description: 'from PNI01 to Edge-TK01' })
          support %w[bgp_proc PNI01 peer_172.16.0.6]
        end
        term_point 'peer_172.16.1.10' do
          attribute({ description: 'from PNI01 to Edge-TK02' })
          support %w[bgp_proc PNI01 peer_172.16.1.10]
        end
      end

      # POI-East
      node 'as65520' do
        support %w[bgp_proc POI-East]
        term_point 'peer_192.168.0.9' do
          attribute({ description: 'from POI-East to Edge-TK01' })
          support %w[bgp_proc POI-East peer_192.168.0.9]
        end
        term_point 'peer_192.168.0.13' do
          attribute({ description: 'from POI-East to Edge-TK02' })
          support %w[bgp_proc POI-East peer_192.168.0.13]
        end
      end

      # inter AS links
      bdlink %w[as65518 peer_172.16.0.5 as65550 peer_172.16.0.6]
      bdlink %w[as65518 peer_172.16.1.9 as65550 peer_172.16.1.10]
      bdlink %w[as65518 peer_192.168.0.10 as65520 peer_192.168.0.9]
      bdlink %w[as65518 peer_192.168.0.14 as65520 peer_192.168.0.13]
    end
  end
end
# rubocop:enable Metrics/MethodLength, Metrics/BlockLength, Metrics/AbcSize
