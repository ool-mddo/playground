# frozen_string_literal: true

module LinkdownSimulation
  # Network subset: connected network elements (node/tp) in a network (layer)
  class NetworkSubset
    # @!attribute [r] elements
    #   return [Array<String>]
    attr_reader :elements
    # @!attribute [rw] flag
    #   @return [Hash]
    attr_accessor :flag

    # @param [Array<String>] element_paths Paths of node/term-point
    def initialize(*element_paths)
      @elements = element_paths || []
      # flags contains key:value, value must be Integer of Boolean(true/false)
      @flag = {}
    end

    # @return [NetworkSubset] self
    def uniq!
      @elements.uniq!
      self
    end

    # @return [Hash]
    def to_data
      { elements: @elements, flag: @flag }
    end

    # for layer3 segment node type checking
    # @return [Array<String>] Found segment node names
    def find_all_multiple_prefix_seg_nodes
      @elements.grep(/.+__Seg.+\+$/)
    end

    # for layer3 segment node type checking
    # @return [Array<String>] Found segment node names
    def find_all_duplicated_prefix_seg_nodes
      @elements.grep(/.+__Seg.+#\d+$/)
    end

    # @param [Symbol] key Key in flag
    # @return [Integer] Count of the flag
    def countup_flag(key)
      @flag[key] = 0 unless @flag.key?(key)
      @flag[key] += 1
    end
  end
end
