# Beanstalk

require 'elasticbeanstalk/healthd'
require 'elasticbeanstalk/log-conf-manager'

if Healthd.enabled?
    manager = ElasticBeanstalk::LogConfManager.new('healthd')

    manager.add '/var/log/healthd/daemon.log*', :types => [:systemtaillogs, :bundlelogs, :rotatelogs]
    manager.log_rotate_hash[:rotate] = '5'
    manager.log_rotate_hash[:size] = '10M'

    manager.write
end

