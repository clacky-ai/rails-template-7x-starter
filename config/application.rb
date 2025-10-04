require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

require_relative '../lib/env_config'

module Myapp
  class Application < Rails::Application

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

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks generators rails])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Configure GoodJob as the Active Job queue adapter
    config.active_job.queue_adapter = :good_job

    # Enable cron-style recurring jobs
    config.good_job.enable_cron = true

    # Configure job execution modes
    config.good_job.execution_mode = :external

    # Load cron configuration from recurring.yml
    cron_config = Rails.application.config_for(:recurring)
    config.good_job.cron = cron_config if cron_config.present?
  end
end
