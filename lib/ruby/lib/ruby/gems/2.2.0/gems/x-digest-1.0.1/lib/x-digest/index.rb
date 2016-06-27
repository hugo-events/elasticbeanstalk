module XDigest
    class Index
        attr_reader :page, :sub_page

        def initialize(page, sub_page, digest)
            @page = page
            @sub_page = sub_page
            @digest = digest
        end

        def mean
            @digest.data[@page].centroids[@sub_page]
        end

        def count
            @digest.data[@page].counts[@sub_page]
        end
    end
end
