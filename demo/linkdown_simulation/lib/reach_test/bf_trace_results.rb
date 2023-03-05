# frozen_string_literal: true

module LinkdownSimulation
  # Batfish traceroute data operations
  class BFTracerouteResults
    # @param [Array<Hash>] bft_result Output of Batfish traceroute query
    def initialize(bft_result)
      @bft_result = bft_result # array
    end

    # @return [Array<Hash>]
    def to_data
      simplify_bft_results(@bft_result[:result])
    end

    private

    # @param [Array<Hash>] bft_results
    # @return [Array<Hash>]
    def simplify_bft_results(bft_results)
      # Flow: {}
      # Traces: [ trace ]
      bft_results.map do |bft_result|
        {
          flow: simplify_flow(bft_result[:Flow]),
          traces: simplify_traces(bft_result[:Traces])
        }
      end
    end

    # @param [Hash] flow Batfish flow
    # @return [Hash] Simplified flow
    def simplify_flow(flow)
      keys = %w[dstIp dstPort ingressInterface ingressNode ipProtocol srcIp srcPort]
      flow.slice(*keys)
    end

    # @param [Array<Hash>] traces
    # @return [Array<Hash>]
    def simplify_traces(traces)
      # disposition: str
      # hops: [ hop ]
      traces.map do |trace|
        {
          disposition: trace[:disposition],
          hops: simplify_hops(trace[:hops])
        }
      end
    end

    # @param [Array<Hash>] hops
    # @return [Array<String>] Simplified hops (list of node[interface])
    def simplify_hops(hops)
      # node: str
      # steps:
      # - action
      # - detail
      hops.map do |hop|
        node = hop[:node]
        received_hop = hop[:steps].find { |step| step[:action] == 'RECEIVED' }
        "#{node}[#{received_hop[:detail][:inputInterface]}]"
      end
    end
  end
end
