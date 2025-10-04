# Extend Rails::Generators::GeneratedAttribute to support enhanced syntax
require "rails/generators/generated_attribute"

Rails::Generators::GeneratedAttribute.singleton_class.prepend(Module.new do
  def valid_index_type?(index_type)
    return true if index_type&.start_with?('default=')
    return true if index_type == 'null'
    return true if index_type == 'serialize'
    super
  end
end)
