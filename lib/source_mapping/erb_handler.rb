require 'action_view'
require_relative 'config'
require_relative 'erb_preprocessor'

module SourceMapping
  class ErbHandler < ActionView::Template::Handlers::ERB
    def call(template, source = nil)
      source ||= template.source

      # Check if source mapping is enabled
      if Config.enabled?
        # Use preprocessor to inject source attributes into HTML tags
        preprocessor = ErbPreprocessor.new(source, template.identifier)
        processed_source = preprocessor.process
        super(template, processed_source)
      else
        super(template, source)
      end
    end
  end
end