# Configure default behavior for skip_before_action to use raise: false
# This prevents exceptions when trying to skip non-existent before_actions

Rails.application.config.to_prepare do
  # Only apply the patch once to avoid multiple aliasing
  unless ActionController::Base.respond_to?(:original_skip_before_action)
    ActionController::Base.class_eval do
      class << self
        # Store original methods
        alias_method :original_skip_before_action, :skip_before_action
        alias_method :original_skip_after_action, :skip_after_action
        alias_method :original_skip_around_action, :skip_around_action

        # Override skip_before_action to default raise: false
        def skip_before_action(*names, **options)
          # Set raise: false as default if not explicitly specified
          options[:raise] = false unless options.key?(:raise)
          original_skip_before_action(*names, **options)
        end

        # Also override other skip_action methods for consistency
        def skip_after_action(*names, **options)
          options[:raise] = false unless options.key?(:raise)
          original_skip_after_action(*names, **options)
        end

        def skip_around_action(*names, **options)
          options[:raise] = false unless options.key?(:raise)
          original_skip_around_action(*names, **options)
        end
      end
    end
  end
end