# frozen_string_literal: true

# Monkey patch to support custom builder names for remote builders
# Overrides the builder_name method to check for custom name first,
# falling back to the default auto-generated name if not specified
#
# This patch will only be applied if Kamal is already loaded
if defined?(Kamal::Commands::Builder::Remote)
  Kamal::Commands::Builder::Remote.class_eval do
    # Override builder_name to check for custom name first
    # If a custom name is specified in the config, use it
    # Otherwise, fall back to the default auto-generated name
    #
    # @return [String] Builder name to use
    def builder_name
      config.builder.custom_name || default_builder_name
    end

    private
      # Original builder_name logic from Kamal gem
      # Generates name based on remote host and registry type
      #
      # @return [String] Auto-generated builder name
      def default_builder_name
        "kamal-remote-#{remote_builder_name_suffix}"
      end
  end
end
