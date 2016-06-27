module XDigest
    module SharedPage
        attr_accessor :active, :counts, :centroids

        def add(value, weight)
            i = 0
            while i < @active
                if centroids[i] >= value
                    if @active >= @page_size
                        new_page = split
                        if i < @page_size / 2
                            add_at i, value, weight
                        else
                            new_page.add_at i - @page_size / 2, 
                                            value, 
                                            weight
                        end
                        return new_page
                    else
                        add_at i, value, weight
                        return
                    end
                end
                i += 1
            end

            if @active >= @page_size
                new_page = split
                new_page.add_at new_page.active, value, weight
                return new_page
            else
                add_at @active, value, weight
                return
            end
        end

        def add_at(index, value, weight)
            if index < @active
                centroids.insert index, value
                counts.insert index, weight
            else
                centroids.insert @active, value
                counts.insert @active, weight
            end

            @active += 1

            self.total_count += weight
        end

        def delete(i)
            w = counts[i]

            centroids.delete_at i
            counts.delete_at i

            @active -= 1

            self.total_count -= w
        end
    end
end
