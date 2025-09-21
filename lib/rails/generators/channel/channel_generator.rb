# frozen_string_literal: true

# Override ActionCable's default channel generator
module Rails
  module Generators
    class ChannelGenerator < NamedBase
      source_root File.expand_path("templates", __dir__)

      argument :actions, type: :array, default: [], banner: "method method"

      class_option :assets, type: :boolean
      class_option :auth, type: :boolean, default: false, desc: "Generate channel with user authentication support"

      check_class_collision suffix: "Channel"

      def create_channel_file
        template "channel.rb", File.join("app/channels", class_path, "#{file_name}_channel.rb")
      end

      def create_channel_javascript_file
        template "channel.js", File.join("app/javascript/channels", class_path, "#{file_name}_channel.js")
      end

      def create_channel_spec_file
        template "channel_spec.rb", File.join("spec/channels", class_path, "#{file_name}_channel_spec.rb")
      end

      def add_channel_to_index
        index_file = "app/javascript/channels/index.js"
        import_statement = "import \"./#{file_name}_channel\""
        
        # Check if the import statement already exists
        if File.exist?(index_file)
          content = File.read(index_file)
          unless content.include?(import_statement)
            # Add the import statement after the consumer import
            append_to_file index_file do
              "#{import_statement}\n"
            end
            say_status :insert, "app/javascript/channels/index.js", :green
          else
            say_status :identical, "app/javascript/channels/index.js", :blue
          end
        else
          # Create the index.js file if it doesn't exist
          create_file index_file, <<~JS
            // Import all the channels to be used by Action Cable
            import "./consumer"
            #{import_statement}
          JS
        end
      end

      def show_completion_message
        say "\n"
        say "Channel: app/channels/#{file_name}_channel.rb", :green
        say "JavaScript: app/javascript/channels/#{file_name}_channel.js", :green
        say "Test: spec/channels/#{file_name}_channel_spec.rb", :green
        say "Updated: app/javascript/channels/index.js (added import)", :green
        if requires_authentication?
          say "Authentication: Enabled (--auth)", :cyan
        else
          say "Authentication: Disabled (use --auth to enable)", :yellow
        end
        say "\n"
        say "Next steps:", :yellow
        say "1. Add your custom logic to the channel methods", :blue
        say "2. Create channel connection when needed: const channel = window.create#{class_name.gsub('Channel', '')}Channel()", :blue
        say "3. Call channel methods like: channel.methodName(data)", :blue
        if requires_authentication?
          say "4. Ensure ActionCable connection is configured for user authentication", :blue
          say "5. Test your channel: bundle exec rspec spec/channels/#{file_name}_channel_spec.rb", :blue
        else
          say "4. Test your channel: bundle exec rspec spec/channels/#{file_name}_channel_spec.rb", :blue
          say "5. Add --auth flag if you need user authentication support", :blue
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
