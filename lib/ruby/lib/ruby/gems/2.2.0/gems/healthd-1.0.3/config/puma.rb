require 'healthd/daemon/options'

tag 'healthd'
environment 'production'
threads 0, 8
bind 'tcp://127.0.0.1:22221'

quiet if Healthd::Daemon::Options.quiet

if Healthd::Daemon::Options.daemonize
    pidfile ENV['HEALTHD_DAEMON_PID'] || Healthd::Daemon::Options.pid_path
    daemonize
end
