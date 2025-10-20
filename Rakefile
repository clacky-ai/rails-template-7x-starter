require_relative "config/application"
Rails.application.load_tasks

if Rake::Task.task_defined?(:test)
  Rake::Task[:test].clear
end

task :test do
  exec 'bundle exec rspec'
end
