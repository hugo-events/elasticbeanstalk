require 'chainsaw/version'
require 'chainsaw/chainsaw'

module Chainsaw
    @@type_map = {
        :string => 0,
        :fixnum => 1,
        :float  => 2
    }

    # == Usage
    #
    #   require 'chainsaw'
    #   chainsaw = Chainsaw.create :separator => ':', :transforms => [nil, nil, :fixnum, :fixnum]
    #   File.open("/etc/passwd") do |file|
    #       chainsaw.cut(file) do |user, uid, _|
    #           # user is String and uid is Fixnum
    #           next unless uid
    #           puts %[#{user} (#{uid})]
    #       end
    #   end
    #
    # Valid transform types are :string (or nil), :fixnum and :float
    #
    # Returns true if any lines were cut
    #
    def self.create(separator: ',', transforms: [], ext: true)
        raise %[separator has to be a single character] unless separator.length == 1

        if ext
            transforms = transforms.collect do |i|
                case i
                when :fixnum
                    @@type_map[:fixnum]
                when :float
                    @@type_map[:float]
                when :string, nil
                    @@type_map[:string]
                else
                    valid_types = @@type_map.keys.collect { |i| %[:#{i}] }.join ', '
                    raise ArgumentError, %[invalid transformation type :#{i}. valid types are #{valid_types}]
                end
            end

            Chainsaw.new separator, transforms
        else
            Handsaw.new separator, transforms
        end
    end

    # Ruby version of Chainsaw. Intented for regression testing
    class Handsaw
        def initialize(separator, transforms)
            @separator = separator
            @transforms = transforms
        end

        def cut(io)
            lines_cut = false

            while line = io.gets
                o = line.split @separator
                o.each_index do |index|
                    case @transforms[index]
                    when :fixnum
                        o[index] = o[index].to_i
                    when :float
                        o[index] = o[index].to_f
                    else
                        o[index] = o[index].strip
                    end
                end

                yield o
                lines_cut = true
            end
            return lines_cut
        end
    end
end
