#! /opt/elasticbeanstalk/lib/ruby/bin/ruby

require 'json'
require 'time'

require 'elasticbeanstalk/http_utils'

PATH = '/etc/elasticbeanstalk/'
INIT_FILE_PATH = File.join(PATH, '.aws-eb-system-initialized')

KEY_FIRST_INIT_TIME = 'first_init_time'
KEY_INSTANCE_ID = 'instance_id'

def instance_id()
    @instanceid ||= ElasticBeanstalk::HttpUtils.download(source_uri: 'http://169.254.169.254/latest/meta-data/instance-id', max_retries: 2)
end

def read_registrar_file(path)
    content = File.read(path)
    JSON.load(content)
rescue
    return {}
end

def write_registrar_file(path, data)
    content = data ? data.to_json : ''
    File.write(path, content)
end

def check_init(path)
    init_registrar = read_registrar_file(path)
    if ! init_registrar.empty? && init_registrar[KEY_INSTANCE_ID] == instance_id
        'reboot_init'
    else
        'first_init'
    end
end

def mark_init(path)
    data = {
        KEY_FIRST_INIT_TIME => Time.now.utc.iso8601,
        KEY_INSTANCE_ID => instance_id,
    }
    write_registrar_file(path, data)
end

if __FILE__ == $0
    begin
        command = ARGV.pop || ''
        category = ARGV.pop || ''
        case category.downcase
        when 'instance-init'
            case command.downcase
            when 'check'
                puts check_init(INIT_FILE_PATH)
            when 'mark'
                mark_init(INIT_FILE_PATH)
            else
                abort("Invalid command '#{command}'.\n")
            end
        else
            abort("Invalid category '#{category}'.\n")
        end
    rescue => e
        abort("#{e.message}\n")
    end
end
