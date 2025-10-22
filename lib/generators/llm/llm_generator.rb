class LlmGenerator < Rails::Generators::Base
  source_root File.expand_path('templates', __dir__)

  desc "Generate LLM service with streaming and blocking API support"

  class_option :skip_service, type: :boolean, default: false, desc: "Skip service file generation"
  class_option :skip_job, type: :boolean, default: false, desc: "Skip job file generation"

  def create_service_file
    return if options[:skip_service]
    template 'llm_service.rb.erb', 'app/services/llm_service.rb'
  end

  def create_job_file
    return if options[:skip_job]
    template 'llm_stream_job.rb.erb', 'app/jobs/llm_stream_job.rb'
  end

  def create_image_generation_service_file
    template 'image_generation_service.rb.erb', 'app/services/image_generation_service.rb'
  end

  def create_image_generation_job_file
    template 'image_generation_job.rb.erb', 'app/jobs/image_generation_job.rb'
  end

  def create_llm_message_validation_concern
    template 'llm_message_validation_concern.rb.erb', 'app/models/concerns/llm_message_validation_concern.rb'
  end

  def update_application_yml
    # LLM base config (shared with ImageGenerationService)
    llm_base_config = <<~YAML

      # LLM Service Configuration (shared with ImageGenerationService)
      LLM_BASE_URL: '<%= ENV.fetch("CLACKY_LLM_BASE_URL", '') %>'
      LLM_API_KEY: '<%= ENV.fetch("CLACKY_LLM_API_KEY", '') %>'
      # LLM Service Configuration end
    YAML

    # LLM-specific config
    llm_specific_config = <<~YAML

      # LLM Service Specific Configuration
      LLM_MODEL: '<%= ENV.fetch("CLACKY_LLM_MODEL", 'gemini-2.5-flash') %>'
      # LLM Service Specific Configuration end
    YAML

    # Image generation config (uses shared LLM_BASE_URL and LLM_API_KEY)
    image_gen_config = <<~YAML

      # Image Generation Service Configuration (uses LLM_BASE_URL and LLM_API_KEY)
      IMAGE_GEN_MODEL: '<%= ENV.fetch("CLACKY_IMAGE_GEN_MODEL", "gemini-2.5-flash-image") %>'
      IMAGE_GEN_SIZE: '1024x1024' # Default image size
      # Image Generation Service Configuration end
    YAML

    # Update application.yml.example
    add_llm_base_config_if_missing('config/application.yml.example', llm_base_config)
    add_llm_specific_config_to_file('config/application.yml.example', llm_specific_config)
    add_image_gen_config_to_file('config/application.yml.example', image_gen_config)

    # Update application.yml if it exists
    add_llm_base_config_if_missing('config/application.yml', llm_base_config)
    add_llm_specific_config_to_file('config/application.yml', llm_specific_config)
    add_image_gen_config_to_file('config/application.yml', image_gen_config)
  end


  def show_usage_instructions
    # Display generated files content
    generated_files = []

    unless options[:skip_service]
      generated_files << 'app/services/llm_service.rb'
    end

    generated_files << 'app/services/image_generation_service.rb'

    unless options[:skip_job]
      generated_files << 'app/jobs/llm_stream_job.rb'
    end

    generated_files << 'app/jobs/image_generation_job.rb'

    generated_files.each do |file_path|
      say "\n"
      say "📄 Generated file (#{file_path}):", :green
      say "━" * 60, :green
      File.readlines(file_path).each_with_index do |line, index|
        say "#{(index + 1).to_s.rjust(4)} │ #{line.chomp}"
      end
      say "━" * 60, :green
      say "✅ This is the latest content - no need to read the file again", :cyan
    end

    say "\n"
    say "LLM Generator completed successfully!", :green

    say "\n📝 Configuration:"
    say "  Environment variables added to config/application.yml.example"
    say "  Configure these in your config/application.yml:"
    say "    LLM_BASE_URL        - API endpoint (e.g., http://localhost:4000/v1)"
    say "    LLM_API_KEY         - Your API key"
    say "    LLM_MODEL           - Model for text generation (e.g., gemini-2.5-flash)"
    say "    IMAGE_GEN_MODEL     - Model for image generation (e.g., gemini-2.5-flash-image)"
    say "    IMAGE_GEN_SIZE      - Default image size (e.g., 1024x1024)"

    say "\n🚀 Usage Examples:"
    say "\n  1. Text Generation (Streaming via ActionCable):"
    say "     LlmStreamJob.perform_later("
    say "       channel_name: \"chat_\#{user_id}\","
    say "       prompt: 'Explain quantum computing',"
    say "       system: 'You are a helpful assistant'"
    say "     )"

    say "\n  2. Image Generation (via ActionCable):"
    say "     ImageGenerationJob.perform_later("
    say "       channel_name: \"images_\#{user_id}\","
    say "       prompt: 'A cat playing with a ball'"
    say "     )"

    say "\n  3. Direct Image Generation (blocking):"
    say "     result = ImageGenerationService.call("
    say "       prompt: 'A beautiful sunset over the ocean'"
    say "     )"
    say "     # result[:images] contains array of base64 image URLs"

    say "\n📚 Next Steps:"
    say "  1. Configure your API keys in config/application.yml"
    say "  2. Use LlmStreamJob for real-time text streaming"
    say "  3. Use ImageGenerationJob for background image generation"

    say "\n🤖 AI Assistant Note:"
    say "  When storing LLM messages, include LlmMessageValidationConcern."
    say "  Don't validate role & content yourself - the concern handles it."
  end

  private

  def add_llm_base_config_if_missing(file_path, llm_base_config)
    if File.exist?(file_path)
      content = File.read(file_path)

      unless content.include?('LLM_BASE_URL') || content.include?('# LLM Service Configuration')
        append_to_file file_path, llm_base_config
        say "Added LLM base configuration to #{File.basename(file_path)}", :green
      else
        say "LLM base configuration already exists in #{File.basename(file_path)}, skipping...", :cyan
      end
    else
      say "#{File.basename(file_path)} not found, skipping...", :yellow
    end
  end

  def add_llm_specific_config_to_file(file_path, llm_specific_config)
    if File.exist?(file_path)
      content = File.read(file_path)

      unless content.include?('# LLM Service Specific Configuration')
        append_to_file file_path, llm_specific_config
        say "Added LLM specific configuration to #{File.basename(file_path)}", :green
      else
        say "LLM specific configuration already exists in #{File.basename(file_path)}, skipping...", :yellow
      end
    else
      say "#{File.basename(file_path)} not found, skipping...", :yellow
    end
  end

  def add_image_gen_config_to_file(file_path, image_gen_config)
    if File.exist?(file_path)
      content = File.read(file_path)

      unless content.include?('# Image Generation Service Configuration')
        append_to_file file_path, image_gen_config
        say "Added Image Generation configuration to #{File.basename(file_path)}", :green
      else
        say "Image Generation configuration already exists in #{File.basename(file_path)}, skipping...", :yellow
      end
    else
      say "#{File.basename(file_path)} not found, skipping...", :yellow
    end
  end
end
