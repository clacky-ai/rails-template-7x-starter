module SourceMapping
  # Configuration for source mapping feature
  class Config
    # The HTML attribute name used to store source location information
    # You can change this to any valid HTML data attribute name
    # For example: 'data-erb-source', 'data-template-location', etc.
    SOURCE_ID_ATTRIBUTE = 'data-clacky-source-loc'

    # Check if source mapping should be enabled
    def self.enabled?
      true
    end

    # Get the main source ID attribute name
    def self.source_id_attribute
      SOURCE_ID_ATTRIBUTE
    end
  end
end
