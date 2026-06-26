# This usually is deployed to /usr/local/etc/unicorn.rb
# and then executed from the rc.d/cccms script
#
#
# unicorn -c /usr/local/etc/unicorn.rb -E production -D

stderr_path "/var/log/unicorn.stderr.log"

rails_env = ENV['RAILS_ENV'] || 'production'

worker_processes (rails_env == 'production' ? 32 : 4)

preload_app true

timeout 30

listen "0.0.0.0:9090", tcp_nopush: false

pid "/usr/local/www/cccms/tmp/pids/unicorn.pid"

before_fork do |server, worker|
  old_pid = Rails.root.to_s + '/tmp/pids/unicorn.pid.oldbin'
  if File.exist?(old_pid) && server.pid != old_pid
    begin
      Process.kill("QUIT", File.read(old_pid).to_i)
    rescue Errno::ENOENT, Errno::ESRCH
      # someone else did our job for us
    end
  end
end

after_fork do |server, worker|
  ActiveRecord::Base.establish_connection
end

user 'www', 'www'
