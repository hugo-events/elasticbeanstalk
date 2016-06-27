# Beanstalk

require 'elasticbeanstalk/healthd'

# httpd logs consumed by healthd need to be rotated only if healthd is enabled and container supports httpd
if Healthd.enabled? && File.exists?('/etc/httpd')
    Healthd.configure_httpd_logging
end

