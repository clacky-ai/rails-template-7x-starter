require_relative "boot"
require "rails/all"

Bundler.require(*Rails.groups)
require_relative '../lib/middleware/clacky_health_check'
require_relative '../lib/env_checker'

require 'open-uri'

module Myapp
  class Application < Rails::Application

    # check environment variables in production
    EnvChecker.check_required_env_vars if Rails.env.production?

    config.generators do |g|
      g.test_framework :rspec,
        fixtures: true,
        view_specs: false,
        helper_specs: false,
        routing_specs: false,
        controller_specs: false,
        request_specs: false
      g.fixture_replacement :factory_bot, dir: "spec/factories"
    end

    # skip credentials
    config.require_master_key = false

    config.generators.assets = false
    config.generators.helper = false
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.2

    config.autoload_lib(ignore: %w[assets tasks generators rails middleware source_mapping])
    config.middleware.insert_before Rails::Rack::Logger, ClackyHealthCheck

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Application name configuration
    config.x.appname = File.read(Rails.root.join('config', 'appname.txt')).strip

    # Configure GoodJob as the Active Job queue adapter
    config.active_job.queue_adapter = :good_job

    # Use vips for Active Storage variants
    config.active_storage.variant_processor = :vips

    # Use custom MailDeliveryJob that inherits from ApplicationJob
    config.action_mailer.delivery_job = "MailDeliveryJob"

    # Enable cron-style recurring jobs
    config.good_job.enable_cron = true

    # Load cron configuration from recurring.yml
    cron_config = Rails.application.config_for(:recurring)
    config.good_job.cron = cron_config if cron_config.present?
  end
end
