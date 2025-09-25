threads_count = ENV.fetch("RAILS_MAX_THREADS", 5)
threads threads_count, threads_count

plugin :tmp_restart

pidfile ENV["PIDFILE"] if ENV["PIDFILE"]
