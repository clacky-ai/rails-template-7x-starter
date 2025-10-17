require 'action_view'
require_relative 'config'
require_relative 'herb_erb_preprocessor'

module SourceMapping
  class ErbHandler < ActionView::Template::Handlers::ERB
    def call(template, source = nil)
      source ||= template.source

      # Check if source mapping is enabled
      if SourceMapping::Config.enabled?
        # Use herb-based preprocessor to inject source attributes into HTML tags
        preprocessor = SourceMapping::HerbErbPreprocessor.new(source, template.identifier)
        processed_source = preprocessor.process
        super(template, processed_source)
      else
        super(template, source)
      end
    end
  end
end