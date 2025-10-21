require "rails/generators/named_base"

module Rails
  module Generators
    class JobGenerator < NamedBase
      source_root File.expand_path('templates', __dir__)

      desc "Generate a job class with spec"

      class_option :queue, type: :string, default: 'default', desc: "Queue name for the job"

      def create_job_file
        template 'job.rb.erb', File.join("app/jobs", class_path, "#{job_file_name}.rb")
      end

      def create_job_spec
        template 'job_spec.rb.erb', File.join("spec/jobs", class_path, "#{job_file_name}_spec.rb")
      end

      def show_completion_message
        # Display generated job file content (only when creating)
        if behavior != :revoke
          job_file = File.join("app/jobs", class_path, "#{job_file_name}.rb")
          say "\n"
          say "📄 Generated job (#{job_file}):", :green
          say "━" * 60, :green
          File.readlines(job_file).each_with_index do |line, index|
            puts "#{(index + 1).to_s.rjust(4)} │ #{line.chomp}"
          end
          say "━" * 60, :green
          say "✅ This is the latest content - no need to read the file again", :cyan
        end
      end

      private

      def job_file_name
        @job_file_name ||= begin
          if file_name.end_with?('_job')
            file_name
          else
            "#{file_name}_job"
          end
        end
      end

      def class_name
        @class_name ||= job_file_name.camelize
      end

      def queue_name
        options[:queue] || 'default'
      end
    end
  end
end
