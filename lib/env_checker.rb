# frozen_string_literal: true

module EnvChecker
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

    def get_public_host_and_port_and_protocol
      default_port = 3000

      if ENV['PUBLIC_HOST'].present?
        return { host: ENV.fetch('PUBLIC_HOST'), port: 443, protocol: 'https' }
      end

      # If CLACKY_PUBLIC_HOST is blank and CLACKY_PREVIEW_DOMAIN_BASE is present,
      # use APP_PORT (default 3000) + CLACKY_PREVIEW_DOMAIN_BASE
      if ENV['CLACKY_PREVIEW_DOMAIN_BASE'].present?
        port = ENV.fetch('APP_PORT', default_port)
        domain_base = ENV.fetch('CLACKY_PREVIEW_DOMAIN_BASE')
        return { host: "#{port}#{domain_base}", port: 443, protocol: 'https' }
      end

      # Rails.logger is not ready here, use puts instead.
      puts "EnvChecker: public host fallback to localhost..."
      return { host: 'localhost', port: default_port, protocol: 'http' }
    end

    # Load environment variable names from application.yml.example
    # Returns an array of hashes: [{ name: 'VAR_NAME', optional: true/false }, ...]
    def load_example_env_vars(example_file = 'config/application.yml.example')
      return [] unless File.exist?(example_file)

      lines = File.readlines(example_file)
      env_var_configs = lines
        .map(&:strip)
        .reject { |line| line.empty? || line.start_with?('#') }
        .map do |line|
          parts = line.split(':', 2)
          next nil if parts.size != 2

          var_name = parts[0].strip
          var_value = parts[1].strip

          # Check if value uses ERB template with ENV.fetch or Env.fetch
          # Pattern: <%= ENV.fetch('CLACKY_xxx') %> or <%= Env.fetch('CLACKY_xxx') %>
          optional = var_value.match?(/<%=\s*(?:ENV|Env)\.fetch\(['"]CLACKY_/)

          { name: var_name, optional: optional }
        end
        .compact

      env_var_configs.uniq { |config| config[:name] }
    end

    # Check if all required environment variables exist and have values
    # Variables are considered optional if:
    # 1. They end with '_OPTIONAL' suffix
    # 2. Their value in application.yml.example uses <%= ENV.fetch('CLACKY_xxx') %>
    # 3. They have a corresponding xxx_DUMMY variable with a value
    def check_required_env_vars(example_env_configs = nil)
      example_env_configs ||= load_example_env_vars

      missing_vars = example_env_configs.reject do |config|
        var_name = config[:name]
        is_optional = config[:optional] || var_name.end_with?('_OPTIONAL')

        # Check if xxx_DUMMY variable exists and has value (allows skipping this check)
        dummy_var_name = "#{var_name}_DUMMY"
        has_dummy = ENV[dummy_var_name].present?

        is_optional || has_dummy || get_env_var(var_name).present?
      end.map { |config| config[:name] }

      if missing_vars.any?
        raise "Config error, missing these env keys: #{missing_vars.join(', ')}"
      end
    end
  end
end
