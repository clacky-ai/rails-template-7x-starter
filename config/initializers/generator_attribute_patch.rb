# Extend Rails::Generators::GeneratedAttribute to support enhanced syntax
require "rails/generators/generated_attribute"

Rails::Generators::GeneratedAttribute.singleton_class.prepend(Module.new do
  def valid_index_type?(index_type)
    return true if index_type&.start_with?('default=')
    return true if index_type == 'null'      # Allow null values (default behavior)
    return true if index_type == 'notnull'   # Disallow null values (null: false)
    return true if index_type == 'required'  # Alias for notnull
    return true if index_type == 'serialize'
    super
  end
end)
