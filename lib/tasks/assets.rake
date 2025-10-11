# Prevent assets:precompile in development environment
if Rails.env.development?
  Rake::Task['assets:precompile'].clear

  namespace :assets do
    task :precompile do
      puts "assets:precompile is not supported in development environment"
      puts "To check js/css issues, please use: npm run build"
    end
  end
end
