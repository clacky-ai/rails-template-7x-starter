require "rails/generators/active_record"

module ActiveRecord
  module Generators
    class MigrationGenerator < ActiveRecord::Generators::Base
      source_root File.expand_path('templates', __dir__)

      argument :attributes, type: :array, default: [], banner: "field[:type][:index] field[:type][:index]"

      class_option :timestamps, type: :boolean
      class_option :primary_key_type, type: :string, desc: "The type for primary key"
      class_option :database, type: :string, aliases: %i(--db), desc: "The database for your migration. By default, the current environment's primary database is used."

      def initialize(args, *options)
        @raw_attributes = args[1..-1] || []
        super
      end

      def create_migration_file
        set_local_assigns!
        validate_file_name!
        migration_template @migration_template, File.join(db_migrate_path, "#{file_name}.rb")
      end

      def show_migration_content
        # Find the most recent migration file matching our file_name
        migration_files = Dir.glob(File.join(db_migrate_path, "*_#{file_name}.rb")).sort
        if migration_files.any?
          latest_migration = migration_files.last
          say "\n"
          say "📄 Generated migration (#{File.basename(latest_migration)}):", :green
          say "━" * 60, :green
          File.readlines(latest_migration).each_with_index do |line, index|
            puts "#{(index + 1).to_s.rjust(4)} │ #{line.chomp}"
          end
          say "━" * 60, :green
          say "✅ This is the latest content - no need to read the file again", :cyan
        end
      end

      private

      attr_reader :migration_action, :join_tables

      def set_local_assigns!
        @migration_template = "migration.rb.erb"
        case file_name
        when /^(add|remove)_.*_(?:to|from)_(.*)/
          @migration_action = $1
          @table_name       = $2.pluralize
        when /^join_table_(.+)/
          @migration_action = "join"
          @join_tables      = $1.split("_")
        when /^create_(.+)/
          @table_name       = $1.pluralize
          @migration_template = "create_table_migration.rb.erb"
        end
      end

      def validate_file_name!
        unless file_name =~ /^[_a-z0-9]+$/
          raise IllegalMigrationNameError.new(file_name)
        end
      end

      def attributes_with_index
        attributes.select { |a| !a.reference? && a.has_index? }
      end

      def foreign_key_type
        type = options[:primary_key_type]
        ", type: :#{type}" if type
      end

      def migration_version
        Rails::VERSION::MAJOR >= 5 ? "[#{Rails::VERSION::MAJOR}.#{Rails::VERSION::MINOR}]" : ""
      end

      def parsed_attributes
        attributes.map.with_index do |attr, index|
          raw_attr = @raw_attributes[index]
          attr_options = parse_raw_attribute_options(raw_attr)

          {
            name: attr.name,
            type: attr.type,
            index: attr.has_index?,
            unique: attr.has_uniq_index?,
            null: attr_options[:null],
            default: attr_options[:default],
            serialize: attr_options[:serialize],
            reference: attr.reference?
          }
        end
      end

      def parse_raw_attribute_options(raw_attr)
        options = { null: true, default: nil, serialize: false }
        return options unless raw_attr

        parts = raw_attr.split(':')
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
          if attr[:reference]
            # Handle reference types with add_reference
            original_attr = attributes.find { |a| a.name == attr[:name] }
            "    add_reference :#{table_name}, :#{attr[:name]}#{original_attr.inject_options}#{foreign_key_type}"
          else
            line = "    add_column :#{table_name}, :#{attr[:name]}, :#{attr[:type]}"

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
          end
        end.compact.join("\n")
      end

      def migration_indexes
        indexes = parsed_attributes.select { |attr| attr[:index] || attr[:unique] }
        return "" if indexes.empty?

        lines = indexes.map do |attr|
          if attr[:unique]
            "    add_index :#{table_name}, :#{attr[:name]}, unique: true"
          else
            "    add_index :#{table_name}, :#{attr[:name]}"
          end
        end

        "\n" + lines.join("\n")
      end

      def table_name
        @table_name
      end
    end
  end
end
