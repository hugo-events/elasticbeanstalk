require 'x-digest/shared_array_digest'
require 'bigdecimal'

module XDigest
    class ArgumentError < ::ArgumentError; end

    class ArrayDigest
        include SharedArrayDigest

        attr_reader :page_size, :compression, :data, :iterator, :index_cache
        attr_accessor :total_weight, :centroid_count

        def initialize(page_size: @@page_size, compression: @@compression)
            raise ArgumentError, %[page size has to be 4 or higher] if page_size < 4

            @total_weight = 0
            @centroid_count = 0
            @page_size = page_size
            @compression = compression
            @data = []
            @index_cache = Hash.new { |hash, key| hash[key] = {} }
            @iterator = DataIterator.new :digest => self
        end

        def add(value, weight=1)
            unless value.kind_of?(Float) || value.kind_of?(BigDecimal)
                raise TypeError, %[value "#{value}" is not Float or BigDecimal]
            end
            unless weight.kind_of?(Fixnum)
                raise TypeError, %[weight "#{weight}" is not Fixnum]
            end

            start = floor value
            start ||= ceil value

            unless start
                add_raw value, weight
            else
                min_distance = Float::MAX
                last_neighbor = 0
                closest = nil
                n = 0.0

                index = 0
                neighbors = inclusive_tail start
                while neighbors.next?
                    neighbor = neighbors.next

                    z = (mean(neighbor) - value).abs
                    if z == 0
                        closest = neighbor
                        n = 1
                        break
                    elsif z <= min_distance
                        min_distance = z
                        last_neighbor = index
                    else
                        break
                    end
                    index += 1
                end

                unless closest
                    sum = head_sum start
                    index = 0
                    neighbors = inclusive_tail start
                    while neighbors.next?
                        neighbor = neighbors.next
                        break if index > last_neighbor

                        z = (mean(neighbor) - value).abs
                        q = (sum + count(neighbor) / 2.0) / total_weight
                        k = 4 * total_weight * q * (1 - q) / compression

                        if (z == min_distance && count(neighbor) + weight <= k)
                            n += 1

                            if rand < 1 / n
                                closest = neighbor
                            end
                        end
                        sum += count(neighbor)
                        index += 1
                    end
                end
    
                unless closest
                    add_raw value, weight
                else
                    if n == 1
                        page = data[closest.page]
                        page.counts[closest.sub_page] += weight
                        page.total_count += weight
                        page.centroids[closest.sub_page] += (value - page.centroids[closest.sub_page]) / page.counts[closest.sub_page]

                        self.total_weight += weight
                    else
                        current_weight = count(closest) + weight
                        center = mean closest
                        center = center + (value - center) / weight
                
                        if mean(increment(closest, -1)) <= center && mean(increment(closest, 1)) >= center
                            page = data[closest.page]
                            page.counts[closest.sub_page] = current_weight
                            page.centroids[closest.sub_page] = center

                            page.total_count += weight
                            self.total_weight += weight
                        else
                            delete closest
                            add_raw center, current_weight
                        end
                    end
                end
            end

            if centroid_count > 20 * compression
                compress
            end
        end

        def create_array_digest
            ArrayDigest.new :page_size => page_size, :compression => compression
        end

        def create_page
            Page.new :size => page_size
        end
    end
end
