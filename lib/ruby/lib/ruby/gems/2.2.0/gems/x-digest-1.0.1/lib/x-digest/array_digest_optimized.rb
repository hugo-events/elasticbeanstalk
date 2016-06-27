require 'x-digest/shared_array_digest'
require 'x-digest/xdigest'

module XDigest
    class ArgumentError < ::ArgumentError; end

    class ArrayDigestOptimized < ArrayDigestExtended
        include SharedArrayDigest

        attr_reader :page_size, :compression, :data, :iterator, :index_cache

        def initialize(page_size: @@page_size, compression: @@compression)
            raise ArgumentError, %[page size has to be 4 or higher] if page_size < 4

            @page_size = page_size
            @compression = compression
            @data = Data.new (1.0 * (20 * compression + 1) / (page_size / 2)).ceil # TODO: 20 is magic!
            @index_cache = Hash.new { |hash, key| hash[key] = {} }
            @iterator = DataIterator.new :digest => self

            super self
        end

        def create_array_digest
            ArrayDigestOptimized.new :page_size => page_size, :compression => compression
        end

        def create_page
            PageOptimized.new :size => page_size
        end
    end
end
