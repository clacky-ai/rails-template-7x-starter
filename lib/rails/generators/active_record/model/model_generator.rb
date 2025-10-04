require "rails/generators/active_record"

module ActiveRecord
  module Generators
    class ModelGenerator < ActiveRecord::Generators::Base
      source_root File.expand_path('templates', __dir__)

      def self.next_migration_number(dirname)
        Time.now.utc.strftime("%Y%m%d%H%M%S")
      end

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

        migration_template "migration.rb.erb", "db/migrate/create_#{table_name}.rb"
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
        say "\n"
        say "Model generated successfully!", :green
        say "📄 Model: app/models/#{singular_name}.rb", :green
        say "📄 Migration: db/migrate/*_create_#{table_name}.rb", :green unless options[:skip_migration]
        say "📄 Factory: spec/factories/#{table_name}.rb", :green unless options[:skip_factory]
        say "📄 Spec: spec/models/#{singular_name}_spec.rb", :green unless options[:skip_spec]
        say "\n"
        say "Next steps:", :yellow
        say "1. Run: rails db:migrate", :blue unless options[:skip_migration]
        say "2. Add validations and associations to the model", :blue
        say "3. Update factory with realistic data", :blue unless options[:skip_factory]
        say "4. Add model specs", :blue unless options[:skip_spec]
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
            # Quote string/text defaults, leave numbers/booleans unquoted
            default_value = if attr[:type].to_s.in?(['string', 'text'])
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
          value = case attr[:type]
                  when 'string', 'text'
                    "{ Faker::Lorem.sentence }"
                  when 'integer'
                    "{ Faker::Number.number(digits: 5) }"
                  when 'decimal', 'float'
                    "{ Faker::Number.decimal(l_digits: 2, r_digits: 2) }"
                  when 'boolean'
                    "{ [true, false].sample }"
                  when 'date'
                    "{ Faker::Date.backward(days: 30) }"
                  when 'datetime', 'timestamp'
                    "{ Faker::Time.backward(days: 30) }"
                  when 'references', 'belongs_to'
                    "{ nil } # TODO: Set up association"
                  else
                    "{ nil } # TODO: Set appropriate value"
                  end

          "    #{attr[:name]} #{value}"
        end.join("\n")
      end

      def model_validations
        validations = []

        parsed_attributes.each do |attr|
          next if attr[:type] == 'references' || attr[:type] == 'belongs_to'

          if !attr[:null]
            validations << "  validates :#{attr[:name]}, presence: true"
          end
        end

        validations.join("\n")
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
