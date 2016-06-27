module XDigest
    class ForwardEnumerator
        attr_accessor :current_page, :current_sub, :current_active

        def initialize(digest:)
            @digest = digest
            @data = digest.data
            @index_cache = @digest.index_cache
        end

        def setup(page, sub_page)
            @stop = false

            if page >= 0 && page < @data.size
                @current_page = page
                @current_sub = sub_page
                @current_active = @data[page].active
            else
                @stop = true
            end
            self
        end

        def page
            @current_page
        end

        def sub_page
            @current_sub
        end

        def mean
            @data[@current_page].centroids[@current_sub]
        end

        def count
            @data[@current_page].counts[@current_sub]
        end

        def next
            raise StopIteration if @stop

            if @current_sub < @current_active
                idx =  @digest.memoized_index(@current_page, @current_sub)

                @current_sub += 1

                return idx
            elsif @current_page < @data.size - 1
                @current_page += 1
                @current_sub = 1
                @current_active = @data[@current_page].active

                idx =  @digest.memoized_index(@current_page, 0)

                return idx
            end

            raise StopIteration
        end

        def next?
            if @stop
                false
            elsif @current_sub < @current_active
                true
            elsif @current_page < @data.size - 1
                true
            else
                false
            end
        end
    end

    class ReverseEnumerator
        def initialize(digest:)
            @digest = digest
            @data = digest.data
            @index_cache = @digest.index_cache
        end

        def setup(page, sub_page)
            if page >= 0 && sub_page < 0
                page -= 1

                if page >= 0
                    sub_page = @data[page].active - 1
                end
            end

            @stop = false

            if page >= 0
                @current_page = page
                @current_sub = sub_page
            else
                @stop = true
            end

            self
        end

        def page
            @current_page
        end

        def sub_page
            @current_sub
        end

        def mean
            @data[@current_page].centroids[@current_sub]
        end

        def count
            @data[@current_page].counts[@current_sub]
        end

        def next
            raise StopIteration if @stop

            if @current_sub >= 0
                idx =  @digest.memoized_index(@current_page, @current_sub)

                @current_sub -= 1

                return idx
            elsif @current_page > 0
                @current_page -= 1
                @current_sub = @data[@current_page].active - 1

                idx =  @digest.memoized_index(@current_page, @current_sub)

                @current_sub -= 1

                return idx
            end

            raise StopIteration
        end

        def next?
            if @stop
                false
            elsif @current_sub >= 0
                true
            elsif @current_page > 0
                true
            else
                false
            end
        end
    end

    class DataIterator
        def initialize(digest:)
            @forward = ForwardEnumerator.new :digest => digest
            @reverse = ReverseEnumerator.new :digest => digest
        end

        def to_enum(page, sub_page)
            @forward.setup page, sub_page
        end

        def to_reverse_enum(page, sub_page)
            @reverse.setup page, sub_page
        end
    end
end
