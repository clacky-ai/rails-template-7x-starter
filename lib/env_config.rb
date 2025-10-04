# frozen_string_literal: true

module EnvConfig
  class << self
    # Get environment variable value, return default value if not exists
    def get_env_var(var_name, default: nil, must: false)
      default ||= ''
      env_var = ENV.fetch(var_name, default)
      env_var = default if env_var.blank?

      if must && env_var.nil?
        raise "get_env_var error, missing key: #{var_name}"
      end

      env_var
    end

    # If CLACKY_PUBLIC_HOST is blank and CLACKY_PREVIEW_DOMAIN_BASE is present,
    # use APP_PORT (default 3000) + CLACKY_PREVIEW_DOMAIN_BASE
    def get_public_host_and_port_and_protocol
      default_port = 3000

      if ENV['CLACKY_PUBLIC_HOST'].present?
        return { host: ENV.fetch('CLACKY_PUBLIC_HOST'), port: 443, protocol: 'https' }
      end

      if ENV['CLACKY_PREVIEW_DOMAIN_BASE'].present?
        port = ENV.fetch('APP_PORT', default_port)
        domain_base = ENV.fetch('CLACKY_PREVIEW_DOMAIN_BASE')
        return { host: "#{port}#{domain_base}", port: 443, protocol: 'https' }
      end

      # Rails.logger is not ready here, use puts instead.
      puts "EnvConfig: public host fallback to localhost..."
      return { host: 'localhost', port: default_port, protocol: 'http' }
    end

    # Load environment variable names from application.yml.example
    def load_example_env_vars(example_file = 'config/application.yml.example')
      return [] unless File.exist?(example_file)

      lines = File.readlines(example_file)
      env_var_names = lines
        .map(&:strip)
        .reject { |line| line.empty? || line.start_with?('#') }
        .map { |line| line.split(':')[0].strip }

      env_var_names.uniq
    end

    # Check if all required environment variables (non _OPTIONAL suffix) exist and have values
    def check_required_env_vars(example_env_vars = nil)
      example_env_vars ||= load_example_env_vars

      missing_vars = example_env_vars.reject do |key|
        key.end_with?('_OPTIONAL') || get_env_var(key).present?
      end

      if missing_vars.any?
        raise "Config error, missing these env keys: #{missing_vars.join(', ')}"
      end
    end
  end
end

# EnvConfig.check_required_env_vars if Rails.env.production?
