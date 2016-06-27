require 'x-digest/shared_page'
require 'x-digest/xdigest'

module XDigest
    class Page
        include SharedPage

        attr_accessor :total_count

        def initialize(size:)
            @page_size = size
            @total_count = 0
            @active = 0
            @centroids = []
            @counts = []
        end

        def split
            raise %[ooops] unless @active == @page_size
            half = @page_size / 2

            tmp_centroids = @centroids.shift(@page_size - half)
            tmp_counts = @counts.shift(@page_size - half)

            new_page = Page.new :size => @page_size
            new_page.centroids = @centroids
            new_page.counts = @counts

            @centroids = tmp_centroids
            @counts = tmp_counts

            @active = @centroids.size
            @total_count = @counts.reduce(&:+)

            new_page.active = new_page.centroids.size
            new_page.total_count = new_page.counts.reduce(&:+)

            return new_page
        end
    end

    class PageOptimized < PageExtended
        include SharedPage

        def initialize(size:)
            @page_size = size
            @active = 0
            @counts = Counts.new size
            @centroids = Centroids.new size

            super @centroids, @counts
        end

        def split
            raise %[ooops] unless @active == @page_size
            half = @page_size / 2

            new_page = PageOptimized.new :size => @page_size

            original_total_count = self.total_count
            migrated_total_count = 0

            start_index = @page_size - half
            (start_index...@active).each do |i|
                current_index = i - start_index

                new_page.centroids[current_index] = @centroids.delete_at start_index
                new_page.counts[current_index] = @counts.delete_at start_index

                migrated_total_count += new_page.counts[current_index]
            end
            @active = @centroids.size

            new_page.active = new_page.centroids.size

            self.total_count = original_total_count - migrated_total_count
            new_page.total_count = migrated_total_count

            return new_page
        end
    end
end
