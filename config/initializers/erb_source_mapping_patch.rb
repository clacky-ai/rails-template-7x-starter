# Automatically inject source location information into HTML elements
# Only enabled in development environment

if Rails.env.development?
  Rails.application.config.after_initialize do
    # Load source mapping modules
    require Rails.root.join('lib/source_mapping/config')
    require Rails.root.join('lib/source_mapping/erb_handler')

    # Check if enabled
    if SourceMapping::Config.enabled?
      # Register custom ERB handler to replace default handler
      ActionView::Template.register_template_handler :erb, SourceMapping::ErbHandler.new

      attr_name = SourceMapping::Config.source_id_attribute
    end
  end
end
