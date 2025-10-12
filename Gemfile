source "https://rubygems.org"
gem "rails", "~> 7.2.2", ">= 7.2.2.1"
gem "puma", ">= 5.0"
gem "jbuilder"
gem "tzinfo-data", platforms: %i[ mswin mswin64 mingw x64_mingw jruby ]
gem "bootsnap", require: false

gem "pg", ">= 1.1"
gem "figaro"
gem "cssbundling-rails"
gem "jsbundling-rails"
gem "propshaft", "~> 1.1.0"
gem "bcrypt"
gem "kaminari"
gem "good_job", "~> 4.6"
gem "friendly_id", "~> 5.5"
gem "rails-i18n", "~> 7.0.10"
gem 'mini_magick', '~> 5.3', '>= 5.3.1'
gem 'ostruct', '~> 0.6.3'
gem "solid_cable", "~> 3.0"
gem "turbo-rails", "~> 2.0"

group :development do
  gem "error_highlight", ">= 0.4.0", platforms: [ :ruby ]
  gem "listen"
end

group :development, :test do
  gem "rspec-rails"
  gem "factory_bot_rails"
  gem "faker"
  gem "debug", platforms: %i[ mri mswin mswin64 mingw x64_mingw ], require: "debug/prelude"
  gem "brakeman", require: false
  gem "rubocop-rails-omakase", require: false
  gem "parser", "3.3.5.0"  # Match Ruby 3.3.5 version
end

group :test do
  gem "database_cleaner"
  gem "launchy"
  gem "capybara"
  gem "selenium-webdriver"
end
