# Beanstalk

require 'elasticbeanstalk/healthd'

# nginx logs consumed by healthd need to be rotated only if healthd is enabled and container supports nginx
if Healthd.enabled? && File.exists?('/etc/nginx/')
    Healthd.configure_nginx_logging
end

