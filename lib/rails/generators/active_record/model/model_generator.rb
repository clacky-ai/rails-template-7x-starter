require "rails/generators/active_record"

module ActiveRecord
  module Generators
    class ModelGenerator < ActiveRecord::Generators::Base
      source_root File.expand_path('templates', __dir__)

      # Store raw attributes before Rails parses them
      def initialize(args, *options)
        # Store raw attribute strings before parent processes them
        @raw_attributes = args[1..-1] || []
        super
      end

      # Parent class handles attributes - we just process them after
      argument :attributes, type: :array, default: [], banner: "field[:type][:index][default=x] field[:type][:index][default=x]"

      class_option :skip_migration, type: :boolean, default: false, desc: "Skip migration file generation"
      class_option :skip_factory, type: :boolean, default: false, desc: "Skip factory file generation"
      class_option :skip_spec, type: :boolean, default: false, desc: "Skip spec file generation"

      def check_name_validity
        # Check for reserved/protected model names
        if protected_model_names.include?(name.downcase.singularize)
          say "Error: Cannot generate model '#{name}'.", :red

          case name.downcase.singularize
          when 'user'
            say "💡 For user authentication, use:", :blue
            say "   rails generate authentication", :blue
          when 'order'
            say "💡 For payment/order system, use:", :blue
            say "   rails generate stripe_pay", :blue
          else
            say "This name is reserved. Please choose a different name.", :yellow
          end

          exit(1)
        end

        # Check for empty or invalid names
        if singular_name.blank?
          say "Error: Model name cannot be empty.", :red
          say "Usage: rails generate model NAME [field[:type][:index] field[:type][:index]]", :yellow
          say "Example: rails generate model product name:string price:decimal", :blue
          exit(1)
        end

        # Check for minimum length
        if singular_name.length < 2
          say "Error: Model name must be at least 2 characters long.", :red
          say "Example: rails generate model post title:string", :blue
          exit(1)
        end
      end

      def generate_model
        check_name_validity
        template "model.rb.erb", "app/models/#{singular_name}.rb"
      end

      def generate_migration
        return if options[:skip_migration]

        migration_template "create_table_migration.rb.erb", "db/migrate/create_#{table_name}.rb"
      end

      def generate_factory
        return if options[:skip_factory]

        template "factory.rb.erb", "spec/factories/#{table_name}.rb"
      end

      def generate_model_spec
        return if options[:skip_spec]

        template "model_spec.rb.erb", "spec/models/#{singular_name}_spec.rb"
      end

      def show_completion_message
        if behavior != :revoke
          # Display generated model file content
          model_file = "app/models/#{singular_name}.rb"
          say "\n"
          say "📄 Generated model (#{model_file}):", :green
          say "━" * 60, :green
          File.readlines(model_file).each_with_index do |line, index|
            puts "#{(index + 1).to_s.rjust(4)} │ #{line.chomp}"
          end
          say "━" * 60, :green
          say "✅ This is the latest content - no need to read the file again", :cyan

          say "\n"
          say "Next steps:", :yellow
          say "1. Run: rails db:migrate", :blue unless options[:skip_migration]
          say "2. Add validations and associations to the model", :blue
          say "3. Update factory with realistic data", :blue unless options[:skip_factory]
          say "4. Add model specs", :blue unless options[:skip_spec]
        end
      end

      private

      def singular_name
        name.underscore.singularize
      end

      def plural_name
        name.underscore.pluralize
      end

      def table_name
        plural_name
      end

      def class_name
        name.classify
      end

      def migration_version
        Rails::VERSION::MAJOR >= 5 ? "[#{Rails::VERSION::MAJOR}.#{Rails::VERSION::MINOR}]" : ""
      end

      def protected_model_names
        %w[
          user
          account
          session
          registration
          password
          order
          payment
          subscription
        ]
      end

      def parsed_attributes
        attributes.map.with_index do |attr, index|
          # Get corresponding raw attribute string
          raw_attr = @raw_attributes[index]
          attr_options = parse_raw_attribute_options(raw_attr)

          {
            name: attr.name,
            type: attr.type,
            index: attr.has_index?,
            unique: attr.has_uniq_index?,
            null: attr_options[:null],
            default: attr_options[:default],
            serialize: attr_options[:serialize]
          }
        end
      end

      def parse_raw_attribute_options(raw_attr)
        options = { null: true, default: nil, serialize: false }
        return options unless raw_attr

        # Parse raw string like "name:string:default=draft:null:serialize"
        parts = raw_attr.split(':')

        # Skip name and type, process remaining parts
        parts[2..-1]&.each do |part|
          if part.start_with?('default=')
            options[:default] = part.split('=', 2)[1]
          elsif part == 'null'
            # Keep null: true (allow null) - this is more intuitive
            # To disallow null, use 'notnull' or 'required' modifier
            options[:null] = true
          elsif part == 'notnull' || part == 'required'
            # Use 'notnull' or 'required' to explicitly disallow null
            options[:null] = false
          elsif part == 'serialize'
            options[:serialize] = true
          end
        end

        options
      end

      def migration_attributes
        parsed_attributes.map do |attr|
          line = "      t.#{attr[:type]} :#{attr[:name]}"

          opts = []
          opts << "null: false" unless attr[:null]

          if attr[:default]
            # Handle datetime/time types with "now" default
            default_value = if attr[:type].to_s.in?(['datetime', 'time', 'timestamp']) && attr[:default] == 'now'
                             "-> { 'CURRENT_TIMESTAMP' }"
                           elsif attr[:type].to_s.in?(['string', 'text'])
                             "\"#{attr[:default]}\""
                           else
                             attr[:default]
                           end
            opts << "default: #{default_value}"
          end

          line += ", #{opts.join(', ')}" if opts.any?
          line
        end.join("\n")
      end

      def migration_indexes
        indexes = parsed_attributes.select { |attr| attr[:index] || attr[:unique] }
        return "" if indexes.empty?

        lines = indexes.map do |attr|
          if attr[:unique]
            "      t.index :#{attr[:name]}, unique: true"
          else
            "      t.index :#{attr[:name]}"
          end
        end

        "\n" + lines.join("\n")
      end

      def factory_attributes
        parsed_attributes.map do |attr|
          type_str = attr[:type].to_s

          # Handle references/belongs_to with association syntax
          if ['references', 'belongs_to'].include?(type_str)
            # Extract association name: user_id → user, category_id → category
            association_name = attr[:name].to_s.sub(/_id$/, '')
            "    association :#{association_name}"
          else
            value = case type_str
                    when 'string'
                      '{ "MyString" }'
                    when 'text'
                      '{ "MyText" }'
                    when 'integer'
                      '{ 1 }'
                    when 'decimal', 'float'
                      '{ 9.99 }'
                    when 'boolean'
                      '{ true }'
                    when 'date'
                      '{ Date.today }'
                    when 'datetime', 'timestamp'
                      '{ Time.current }'
                    else
                      '{ nil }'
                    end

            "    #{attr[:name]} #{value}"
          end
        end.join("\n")
      end

      def model_validations
        # Don't auto-generate presence validations
        # Database null: false constraint prevents NULL, but allows empty strings ''
        # This is important for scenarios like streaming where content starts empty
        # Developers should add explicit validations in models or concerns as needed
        ""
      end

      def belongs_to_associations
        # Generate belongs_to for references/belongs_to fields
        reference_attrs = parsed_attributes.select do |attr|
          ['references', 'belongs_to'].include?(attr[:type].to_s)
        end

        return "" if reference_attrs.empty?

        associations = reference_attrs.map do |attr|
          # Extract association name: user_id → user, category_id → category
          association_name = attr[:name].to_s.sub(/_id$/, '')
          "  belongs_to :#{association_name}"
        end

        associations.join("\n")
      end

      def serialized_attributes_declarations
        # Only serialize text/string fields, not json/jsonb (they're handled automatically)
        serialized_attrs = parsed_attributes.select do |attr|
          attr[:serialize] && !['json', 'jsonb'].include?(attr[:type].to_s)
        end

        return "" if serialized_attrs.empty?

        declarations = serialized_attrs.map do |attr|
          "  serialize :#{attr[:name]}, coder: JSON"
        end

        declarations.join("\n")
      end
    end
  end
end
