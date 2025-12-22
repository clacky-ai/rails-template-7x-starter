# frozen_string_literal: true

# Monkey patch to add custom builder name support to Kamal
# This allows specifying a pre-configured builder instead of auto-generating names
#
# Usage in config/deploy.yml:
#   builder:
#     remote: ssh://user@host
#     name: my-custom-builder  # Use existing builder with this name
#
# This patch will only be applied if Kamal is already loaded
if defined?(Kamal::Configuration::Builder)
  Kamal::Configuration::Builder.class_eval do
    # Returns custom builder name if specified in config, nil otherwise
    # This allows users to specify a pre-existing builder with custom BuildKit configuration
    #
    # @return [String, nil] Custom builder name from config or nil
    def custom_name
      builder_config["name"]
    end
  end
end
