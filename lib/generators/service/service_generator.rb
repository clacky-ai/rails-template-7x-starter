class ServiceGenerator < Rails::Generators::NamedBase
  source_root File.expand_path('templates', __dir__)

  desc "Generate a service class"

  def create_service_file
    check_protected_names
    template 'service.rb.erb', "app/services/#{file_name}.rb"
  end

  def create_service_spec
    template 'service_spec.rb.erb', "spec/services/#{file_name}_spec.rb"
  end

  def show_completion_message
    # Display generated service file content (only when creating)
    if behavior != :revoke
      service_file = "app/services/#{file_name}.rb"
      say "\n"
      say "📄 Generated service (#{service_file}):", :green
      say "━" * 60, :green
      File.readlines(service_file).each_with_index do |line, index|
        puts "#{(index + 1).to_s.rjust(4)} │ #{line.chomp}"
      end
      say "━" * 60, :green
      say "✅ This is the latest content - no need to read the file again", :cyan
    end
  end

  private

  def file_name
    if name.downcase.end_with?('service')
      base_name = name.gsub(/service$/i, '')
      standardized_base = standardize_class_name(base_name).underscore
      "#{standardized_base}_service"
    else
      standardized_name = standardize_class_name(name).underscore
      "#{standardized_name}_service"
    end
  end

  def class_name
    if name.downcase.end_with?('service')
      base_name = name.gsub(/service$/i, '')
      standardized_base = standardize_class_name(base_name)
      "#{standardized_base}Service"
    else
      standardized_name = standardize_class_name(name)
      "#{standardized_name}Service"
    end
  end

  def standardize_class_name(name)
    name.underscore.classify
  end

  def check_protected_names
    base_name = name.gsub(/service$/i, '').underscore

    if base_name == 'llm'
      say "Error: Cannot generate service with name 'llm'.", :red
      say "Use the dedicated LLM generator instead:", :yellow
      say "  rails generate llm", :blue
      say "\nThis will generate:", :green
      say "  - LlmService for synchronous/asynchronous API calls", :green
      say "  - LlmJob for background processing", :green
      say "  - LlmRequest model for tracking requests", :green
      say "  - Auto-configure LLM environment variables", :green
      exit(1)
    end
  end

end
