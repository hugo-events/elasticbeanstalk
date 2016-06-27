require 'x-digest/data_iterator'
require 'x-digest/index'
require 'x-digest/page'
require 'x-digest/centroid'

module XDigest
    class ArgumentError < ::ArgumentError; end

    module SharedArrayDigest
        @@page_size = 32
        @@compression = 100

        def compress
            tmp = centroids
            clear

            tmp.shuffle.each { |i| add i.mean, i.count }
        end

        def size
            total_weight
        end

        def cdf(value)
            if size == 0
                return Float::NAN
            end

            if size == 1
                return x < data.first.centroids.first ? 0 : 1
            end

            r = 0
            enum = iterator.to_enum 0, 0
            a = enum.next
            b = enum.next

            left = (b.mean - a.mean) / 2
            right = left

            while enum.next?
                if value < a.mean + right
                    return (r + a.count * interpolate(value, a.mean - left, a.mean + right)) / total_weight
                end

                r += a.count
                a = b
                b = enum.next

                left = right
                right = (b.mean - a.mean) / 2
            end

            left = right
            a = b

            if x < a.mean + right
                return (r + a.count * interpolate(value, a.mean - left, a.mean + right)) / total_weight
            else
                return 1
            end
        end

        def interpolate(x, x0, x1)
            (x - x0) / (x1 - x0)
        end

        def quantile(q)
            if q < 0 || q > 1
                raise ArgumentError, %[q should be in [0,1], got #{q}"]
            end

            if centroid_count == 0
                return Float::NAN
            elsif centroid_count == 1
                return data[0].centroids[0]
            end

            index = q * (size - 1)
            previous_mean = Float::NAN
            previous_index = 0

            total = 0
            first_page = 0
            while first_page < data.size - 1 && total + data.at(first_page).total_count < index
                total += data.at(first_page).total_count
                first_page += 1
            end

            if first_page == 0
                enum = iterator.to_enum 0, 0
            else
                previous_page_index = first_page - 1
                previous_page = data.at previous_page_index

                raise %[oops] unless previous_page.active > 0

                last_sub_page = previous_page.active - 1
                previous_mean = previous_page.centroids[last_sub_page]
                previous_index = total - (previous_page.counts[last_sub_page] + 1.0) / 2

                enum = iterator.to_enum first_page, 0
            end

            while true
                next_item = enum.next
                next_index = total + (next_item.count - 1.0) / 2

                if next_index >= index
                    if previous_mean.respond_to?(:nan?) && previous_mean.nan?
                        raise %[oops] unless total == 0
                        return next_item.mean
                    end

                    return weighted_quantile(previous_index, index, next_index, previous_mean, next_item.mean)
                elsif ! enum.next?
                    return next_item.mean
                end
                total += next_item.count
                previous_mean = next_item.mean
                previous_index = next_index
            end
        end

        def weighted_quantile(previous_index, index, next_index, previous_mean, next_mean)
            delta = next_index - previous_index
            previous_weight = (next_index - index) / delta
            next_weight = (index - previous_index) / delta
            previous_mean * previous_weight + next_mean * next_weight
        end

        def centroids
            r = []
            enum = iterator.to_enum 0, 0
            while enum.next?
                index = enum.next
                centroid = Centroid.new index.mean, index.count

                r << centroid
            end
            r
        end

        def all_after(x)
            if data.size == 0
                return iterator.to_enum 0, 0
            end

            index = 1
            while index < data.size
                if data[index].centroids[0] >= x
                    previous_page = data[index - 1]

                    active_index = 0
                    while active_index < previous_page.active
                        if previous_page.centroids[active_index] > x
                            return iterator.to_enum index - 1, active_index
                        end
                        active_index += 1
                    end
                    return iterator.to_enum index, 0
                end
                index += 1
            end

            last_page = data.last
            index = 0
            while index < last_page.active
                if last_page.centroids[index] > x
                    return iterator.to_enum data.size - 1, index
                end
                index += 1
            end
            return iterator.to_enum data.size, 0
        end

        def floor(x)
            rx = all_before(x)

            unless rx.next?
                return nil
            end

            r = rx.next
            z = r

            while rx.next? && mean(z) == x
                r = z
                z = rx.next
            end
            r
        end

        def ceil(x)
            r = all_after x
            return r.next? ? r.next : nil
        end

        def all_before(x)
            if data.size == 0
                return iterator.to_enum 0, 0
            end

            index = 1
            data_size = data.size
            while index < data_size
                if data[index].centroids[0] > x
                    previous = data[index - 1]
                    previous_index = 0
                    previous_active = previous.active
                    previous_centroids = previous.centroids
                    while previous_index < previous_active
                        if previous_centroids[previous_index] > x
                            return iterator.to_reverse_enum index - 1, previous_index - 1
                        end
                        previous_index += 1
                    end
                    return iterator.to_reverse_enum index, -1
                end
                index += 1
            end

            last_page = data.last
            index = 0
            while index < last_page.active
                if last_page.centroids[index] > x
                    return iterator.to_reverse_enum data.size - 1, index - 1
                end
                index += 1
            end
            return iterator.to_reverse_enum data.size, -1
        end

        def increment(x, delta)
            i = x.page
            j = x.sub_page + delta

            while i < data.size && j >= data[i].active
                j -= data[i].active
                i += 1
            end

            while i > 0 && j < 0
                i -= 1
                j += data[i].active
            end

            memoized_index i, j
        end

        def delete(index)
            self.total_weight -= count(index)
            self.centroid_count -= 1
            data[index.page].delete(index.sub_page)
        end

        def inclusive_tail(start)
            iterator.to_enum start.page, start.sub_page
        end

        def add_raw(value, weight)
            if self.centroid_count == 0
                page = create_page
                page.add value, weight

                self.total_weight += weight
                self.centroid_count += 1

                data << page
            else
                index = 1
                while index < data.size
                    if data[index].centroids[0] > value
                        new_page = data[index - 1].add value, weight

                        self.total_weight += weight
                        self.centroid_count += 1

                        if new_page
                            data.insert index, new_page
                        end
                        return
                    end
                    index += 1
                end

                new_page = data.last.add value, weight

                self.total_weight += weight
                self.centroid_count += 1

                if new_page
                    data << new_page
                end
            end
        end

        def merge(other)
            x = create_array_digest

            [centroids, other.centroids].each do |source|
                source.shuffle.each do |centroid|
                    x.add centroid.mean, centroid.count
                end
            end
            x
        end

        def merge!(other)
            other.centroids.shuffle.each do |centroid|
                add centroid.mean, centroid.count
            end
        end

        def head_sum(limit)
            r = 0
            i = 0

            limit_page = limit.page
            while i < limit_page
                r += data[i].total_count
                i += 1
            end

            if limit.page < data.size
                i = 0

                limit_page = data[limit.page]
                limit_sub_page = limit.sub_page
                limit_page_counts = limit_page.counts
                while i < limit_sub_page
                    r += limit_page_counts[i]
                    i += 1
                end 
            end
            r
        end

        def mean(index)
            data[index.page].centroids[index.sub_page]
        end

        def count(index)
            data[index.page].counts[index.sub_page]
        end

        def clear
            self.total_weight = 0
            self.centroid_count = 0

            data.clear
        end

        def export(round: false)
            centroids = []
            enum = iterator.to_enum 0, 0

            while enum.next?
                index = enum.next
                current = data.at index.page

                mean = current.centroids[index.sub_page]
                mean = mean.round round if round
                count = current.counts[index.sub_page]

                centroids << [mean, count]
            end
            centroids
        end

        def import(centroids)
            centroids.each do |centroid|
                add centroid[0], centroid[1]
            end
        end

        def memoized_index(page_index, sub_index)
            index_cache[page_index][sub_index] ||= begin
                Index.new page_index, sub_index, self
            end
        end
    end
end
