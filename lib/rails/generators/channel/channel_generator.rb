# frozen_string_literal: true

# Override ActionCable's default channel generator
module Rails
  module Generators
    class ChannelGenerator < NamedBase
      source_root File.expand_path("templates", __dir__)


      class_option :assets, type: :boolean
      class_option :auth, type: :boolean, default: false, desc: "Generate channel with user authentication support"

      check_class_collision suffix: "Channel"

      def create_base_channel_controller
        base_controller_path = "app/javascript/controllers/base_channel_controller.ts"

        # Only create if it doesn't exist (avoid duplicate generation)
        # Never remove on destroy (may be used by other channels)
        if behavior != :revoke && !File.exist?(base_controller_path)
          template "base_channel_controller.ts", base_controller_path
        end
      end

      def create_channel_file
        template "channel.rb", File.join("app/channels", class_path, "#{file_name}_channel.rb")
      end

      def create_channel_stimulus_controller
        template "ui_controller.ts.erb", File.join("app/javascript/controllers", class_path, "#{file_name}_controller.ts")
      end

      def create_channel_spec_file
        template "channel_spec.rb", File.join("spec/channels", class_path, "#{file_name}_channel_spec.rb")
      end

      def add_channel_to_stimulus_index
        index_file = "app/javascript/controllers/index.ts"
        controller_class_name = "#{file_name.camelize}Controller"
        import_statement = "import #{controller_class_name} from \"./#{file_name}_controller\""
        register_statement = "application.register(\"#{file_name.dasherize}\", #{controller_class_name})"

        if File.exist?(index_file)
          if behavior == :revoke
            # Read, filter, and write back
            content = File.read(index_file)
            original_content = content.dup

            # Remove import line
            content = content.lines.reject { |line| line.include?(import_statement) }.join

            # Remove registration line
            content = content.lines.reject { |line| line.include?(register_statement) }.join

            if content != original_content
              File.write(index_file, content)
              say_status :remove, "Removed import and registration from app/javascript/controllers/index.ts", :green
            else
              say_status :skip, "Nothing to remove from app/javascript/controllers/index.ts", :yellow
            end
          else
            content = File.read(index_file)

            # Add import statement if not exists
            unless content.include?(import_statement)
              # Insert after existing imports
              inject_into_file index_file, "#{import_statement}\n", after: /import.*_controller"\n(?=\n)/
              say_status :insert, "Added import to app/javascript/controllers/index.ts", :green
            else
              say_status :identical, "Import already exists in app/javascript/controllers/index.ts", :blue
            end

            # Reload content after potential import injection
            content = File.read(index_file)

            # Add registration if not exists
            unless content.include?(register_statement)
              # Insert after existing registrations
              inject_into_file index_file, "#{register_statement}\n", after: /application\.register\(.*\)\n(?=\n)/
              say_status :insert, "Added registration to app/javascript/controllers/index.ts", :green
            else
              say_status :identical, "Registration already exists in app/javascript/controllers/index.ts", :blue
            end
          end
        else
          say_status :error, "app/javascript/controllers/index.ts not found", :red
          unless behavior == :revoke
            say "Please add the following manually:", :yellow
            say "Import: #{import_statement}", :yellow
            say "Register: #{register_statement}", :yellow
          end
        end
      end

      def show_completion_message
        if behavior == :revoke
          say "\n"
          say "✅ Removed #{file_name.camelize}Channel", :green
          say "📝 Files removed:", :blue
          say "   - app/channels/#{file_name}_channel.rb", :blue
          say "   - app/javascript/controllers/#{file_name}_controller.ts", :blue
          say "   - spec/channels/#{file_name}_channel_spec.rb", :blue
          say "   - Import and registration from app/javascript/controllers/index.ts", :blue
          say "\n"
          say "ℹ️  Note: base_channel_controller.ts was not removed (may be used by other channels)", :yellow
          say "\n"
        else
          say "\n"
          say "✅ Generated #{file_name.camelize}Channel (WebSocket + UI controller)", :green
          say "\n"
          say "🎯 This controller handles BOTH WebSocket AND UI interactions", :yellow
          say "   Don't create additional #{file_name} controllers - extend this one!", :yellow
          say "\n"
          say "📝 Edit: app/javascript/controllers/#{file_name}_controller.ts", :blue
          say "🧪 Test: bundle exec rspec spec/channels/#{file_name}_channel_spec.rb", :blue
          if requires_authentication?
            say "🔐 Authentication: Enabled", :cyan
          else
            say "🔓 Authentication: Disabled (use --auth to enable)", :yellow
          end
          say "\n"
        end
      end

      private

      def file_name
        @_file_name ||= super.sub(/_channel\z/i, "")
      end

      def channel_name
        "#{class_name}Channel"
      end

      def stream_name
        @stream_name ||= "#{file_name}_#{rand(1000..9999)}"
      end

      def javascript_channel_name
        file_name.camelize(:lower)
      end

      def requires_authentication?
        options[:auth]
      end
    end
  end
end
