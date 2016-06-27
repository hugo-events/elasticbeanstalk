module AWS::EB::SQSD::Version
    @@sqsd_version = %[2.3]
    @@sqsd_full_version = %[2.3 (2016-03-17)]

    def version
        AWS::EB::SQSD::Version.version
    end

    def full_version
        AWS::EB::SQSD::Version.full_version
    end

    def self.version
        @@sqsd_version
    end

    def self.full_version
        @@sqsd_full_version
    end
end
