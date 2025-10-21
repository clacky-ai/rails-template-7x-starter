class ImageGenerationGenerator < Rails::Generators::Base
  source_root File.expand_path('templates', __dir__)

  desc "Generate Image Generation service using OpenRouter/OpenAI image generation API"

  def create_service_file
    template 'image_generation_service.rb.erb', 'app/services/image_generation_service.rb'
  end

  def create_job_file
    template 'image_generation_job.rb.erb', 'app/jobs/image_generation_job.rb'
  end

  def update_application_yml
    image_gen_config = <<~YAML

      # Image Generation Service Configuration (uses LLM_BASE_URL and LLM_API_KEY)
      IMAGE_GEN_MODEL: '<%= ENV.fetch("CLACKY_IMAGE_GEN_MODEL", "google/gemini-2.0-flash-exp:free") %>'
      IMAGE_GEN_SIZE: '1024x1024' # Default image size
      # Image Generation Service Configuration end
    YAML

    # Update application.yml.example
    add_config_to_file('config/application.yml.example', image_gen_config)

    # Update application.yml if it exists
    add_config_to_file('config/application.yml', image_gen_config)
  end

  def show_usage_instructions
    # Display generated service file
    service_file = 'app/services/image_generation_service.rb'
    say "\n"
    say "📄 Generated service (#{service_file}):", :green
    say "━" * 60, :green
    File.readlines(service_file).each_with_index do |line, index|
      say "#{(index + 1).to_s.rjust(4)} │ #{line.chomp}"
    end
    say "━" * 60, :green
    say "✅ This is the latest content - no need to read the file again", :cyan

    # Display generated job file
    job_file = 'app/jobs/image_generation_job.rb'
    say "\n"
    say "📄 Generated job (#{job_file}):", :green
    say "━" * 60, :green
    File.readlines(job_file).each_with_index do |line, index|
      say "#{(index + 1).to_s.rjust(4)} │ #{line.chomp}"
    end
    say "━" * 60, :green
    say "✅ This is the latest content - no need to read the file again", :cyan

    say "\n"
    say "Image Generation Generator completed successfully!", :green

    say "\n📝 Configuration:"
    say "  Environment variables added to config/application.yml.example"
    say "  Configure these in your config/application.yml:"
    say "    LLM_BASE_URL        - API endpoint (shared with LlmService)"
    say "    LLM_API_KEY         - Your API key (shared with LlmService)"
    say "    IMAGE_GEN_MODEL     - Model name (e.g., gemini-2.5-flash-image)"
    say "    IMAGE_GEN_SIZE      - Image size (e.g., 1024x1024, 512x512)"

    say "\n🚀 Usage Examples:"
    say "  # Direct usage (blocking)"
    say "  result = ImageGenerationService.call("
    say "    prompt: 'A beautiful sunset over mountains'"
    say "  )"
    say "  # => { images: ['data:image/png;base64,...'] }"
    say ""
    say "  # Background job (recommended to avoid blocking)"
    say "  ImageGenerationJob.perform_later("
    say "    channel_name: 'user_123',"
    say "    prompt: 'A cute cat'"
    say "  )"

    say "\n📚 Next Steps:"
    say "  1. Configure LLM_BASE_URL and LLM_API_KEY in config/application.yml"
    say "  2. Set IMAGE_GEN_MODEL for your image generation model"
    say "  3. Use ImageGenerationJob for background processing (recommended)"
    say "  4. Or use ImageGenerationService.call for direct/synchronous calls"
  end

  private

  def add_config_to_file(file_path, config)
    if File.exist?(file_path)
      content = File.read(file_path)

      unless content.include?('# Image Generation Service Configuration')
        append_to_file file_path, config
        say "Added Image Generation configuration to #{File.basename(file_path)}", :green
      else
        say "Image Generation configuration already exists in #{File.basename(file_path)}, skipping...", :yellow
      end
    else
      say "#{File.basename(file_path)} not found, skipping...", :yellow
    end
  end
end
