# Minimal patch: Only extend validation to allow default= and null
require "rails/generators/generated_attribute"
require "rails/generators/model_helpers"

Rails::Generators::GeneratedAttribute.singleton_class.prepend(Module.new do
  def valid_index_type?(index_type)
    return true if index_type&.start_with?('default=')
    return true if index_type == 'null'
    super
  end
end)

# Hook generator - delegates to active_record:model
module Rails
  module Generators
    class ModelGenerator < NamedBase
      include Rails::Generators::ModelHelpers

      argument :attributes, type: :array, default: [], banner: "field[:type][:index] field[:type][:index]"

      hook_for :orm, required: true, desc: "ORM to be invoked"

      class << self
        delegate(:desc, to: :orm_generator)
      end
    end
  end
end
