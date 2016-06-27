require 'x-digest/version'
require 'x-digest/array_digest_optimized'
require 'x-digest/array_digest'

module XDigest
    def self.create(ext: nil, **options)
        if ext.nil?
            ext = case ENV['EXT']
            when '0'
                false
            else
                true
            end
        end

        if ext
            ArrayDigestOptimized.new **options
        else
            ArrayDigest.new **options
        end
    end
end
