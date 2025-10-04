# Compatibility layer for Rails serialize syntax changes
# Rails 7.0: serialize :field, Hash
# Rails 7.1+: serialize :field, coder: JSON
#
# This allows both old and new syntax to work

module ActiveRecord
  module AttributeMethods
    module Serialization
      module ClassMethods
        # Store original method
        alias_method :original_serialize, :serialize

        # Override serialize to handle both old and new syntax
        def serialize(attr_name, class_name_or_coder = nil, **options)
          # Handle old syntax: serialize :field, Hash or serialize :field, JSON
          if class_name_or_coder.is_a?(Class) && options[:coder].nil?
            case class_name_or_coder.name
            when 'Hash', 'Array'
              # Old syntax: serialize :field, Hash
              # Convert to new syntax: serialize :field, coder: JSON, type: Hash
              return original_serialize(attr_name, coder: JSON, type: class_name_or_coder, **options)
            when 'JSON'
              # Old syntax: serialize :field, JSON
              # Convert to new syntax: serialize :field, coder: JSON
              return original_serialize(attr_name, coder: JSON, **options)
            end
          end

          # Handle old constant-based coder: serialize :field, JSON
          if class_name_or_coder == JSON && options[:coder].nil?
            return original_serialize(attr_name, coder: JSON, **options)
          end

          # Pass through new syntax - if class_name_or_coder is provided and not handled above
          # it means we're using new syntax so we shouldn't pass it as a positional arg
          if class_name_or_coder.nil? || options[:coder].present?
            # New syntax: all options are keyword args
            original_serialize(attr_name, **options)
          else
            # Fallback - shouldn't happen with proper usage
            original_serialize(attr_name, **options)
          end
        end
      end
    end
  end
end
