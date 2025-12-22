# frozen_string_literal: true

# Monkey patch to add 'name' field to builder configuration validation
# This allows the validator to accept the custom 'name' field
#
# We need to patch validate_against_example! to skip validation for 'name' field

if defined?(Kamal::Configuration::Validator)
  Kamal::Configuration::Validator.class_eval do
    # Store original method
    alias_method :original_validate_against_example!, :validate_against_example!

    # Override to skip validation for 'name' field in builder config
    def validate_against_example!(validation_config, example)
      # If we're in builder context and config has 'name', validate without it
      if context == "builder" && validation_config.is_a?(Hash) && validation_config.key?("name")
        # Validate all fields except 'name'
        config_without_name = validation_config.except("name")
        original_validate_against_example!(config_without_name, example)

        # Separately validate that 'name' is a string
        with_context("name") do
          validate_type! validation_config["name"], String
        end
      else
        original_validate_against_example!(validation_config, example)
      end
    end
  end
end
