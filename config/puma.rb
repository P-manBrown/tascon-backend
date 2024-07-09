threads_count = ENV.fetch("RAILS_MAX_THREADS", 5)
threads threads_count, threads_count

environment ENV.fetch("RAILS_ENV") { "development" }

app_root = File.expand_path("..", __dir__)
bind "unix://#{app_root}/tmp/sockets/puma.sock"
if ENV["RAILS_ENV"] == "production"
  stdout_redirect "#{app_root}/log/puma.stdout.log", "#{app_root}/log/puma.stderr.log", true
end

plugin :tmp_restart
