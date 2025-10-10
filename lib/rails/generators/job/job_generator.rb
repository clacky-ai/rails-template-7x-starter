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
