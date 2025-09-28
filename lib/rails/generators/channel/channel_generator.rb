# frozen_string_literal: true

# Override ActionCable's default channel generator
module Rails
  module Generators
    class ChannelGenerator < NamedBase
      source_root File.expand_path("templates", __dir__)


      class_option :assets, type: :boolean
      class_option :auth, type: :boolean, default: false, desc: "Generate channel with user authentication support"

      check_class_collision suffix: "Channel"

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
          content = File.read(index_file)

          # Add import statement if not exists
          unless content.include?(import_statement)
            # Insert after existing imports
            inject_into_file index_file, "#{import_statement}\n", after: /import.*_controller"\n(?=\n)/
            say_status :insert, "Added import to app/javascript/controllers/index.ts", :green
          else
            say_status :identical, "Import already exists in app/javascript/controllers/index.ts", :blue
          end

          # Add registration if not exists
          unless content.include?(register_statement)
            # Insert after existing registrations
            inject_into_file index_file, "#{register_statement}\n", after: /application\.register\(.*\)\n(?=\n)/
            say_status :insert, "Added registration to app/javascript/controllers/index.ts", :green
          else
            say_status :identical, "Registration already exists in app/javascript/controllers/index.ts", :blue
          end
        else
          say_status :error, "app/javascript/controllers/index.ts not found", :red
          say "Please add the following manually:", :yellow
          say "Import: #{import_statement}", :yellow
          say "Register: #{register_statement}", :yellow
        end
      end

      def show_completion_message
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
