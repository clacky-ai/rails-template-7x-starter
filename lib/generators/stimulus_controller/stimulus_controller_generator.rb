class StimulusControllerGenerator < Rails::Generators::NamedBase
  source_root File.expand_path('templates', __dir__)

  desc 'Generate a Stimulus controller with TypeScript support'


  def create_stimulus_controller
    check_name_validity

    controller_name = file_name_without_controller
    class_name = "#{controller_name.camelize}Controller"
    controller_path = "app/javascript/controllers/#{controller_name}_controller.ts"

    # Check if file already exists
    if File.exist?(controller_path)
      say "⚠️  Controller file already exists: #{controller_path}", :yellow
      say "💡 Please read and modify the existing code, following the conventions within.", :blue
      return
    end

    template 'controller.ts.erb', controller_path

    insert_into_index_ts(controller_name, class_name)

    say "✅ Stimulus controller '#{controller_name}' created successfully!", :green
    say "📁 Controller file: #{controller_path}", :blue
    say "📄 Added to: app/javascript/controllers/index.ts", :blue
  end

  # def create_system_test
    # controller_name = file_name_without_controller
    # template 'system_test.rb.erb', "spec/system/#{controller_name}_controller_spec.rb"

    # say "📋 System test created: spec/system/#{controller_name}_controller_spec.rb", :blue
  # end

  private

  def check_name_validity
    # Check for reserved words first (before processing)
    if %w[controller controllers].include?(name.downcase)
      say "Error: Cannot generate controller with name '#{name}'.", :red
      say "This name is reserved. Please choose a different name.", :yellow
      say "Example: rails generate stimulus_controller modal", :blue
      exit(1)
    end

    # Check for empty or invalid names after processing
    if base_name_without_controller.blank?
      say "Error: Controller name cannot be empty after processing.", :red
      say "Usage: rails generate stimulus_controller NAME", :yellow
      say "Example: rails generate stimulus_controller modal", :blue
      exit(1)
    end

    # Check for protected stimulus controller names
    protected_controller_name = base_name_without_controller.underscore.dasherize
    if protected_stimulus_controller_names.include?(protected_controller_name)
      say "Error: Cannot generate stimulus controller with name '#{protected_controller_name}'.", :red
      say "This name is protected as it conflicts with existing system controllers.", :yellow
      say "\nSolutions:", :blue
      say "1. Choose a different controller name to avoid conflicts", :blue
      say "2. Use a prefix like: my-#{protected_controller_name}, custom-#{protected_controller_name}", :blue
      say "Example: rails generate stimulus_controller my_dropdown", :blue
      exit(1)
    end

    # Check for potential conflicts with existing JavaScript keywords
    reserved_names = %w[constructor prototype window document undefined null]
    if reserved_names.include?(base_name_without_controller.downcase)
      say "Error: '#{base_name_without_controller}' is a reserved JavaScript name.", :red
      say "Please choose a different controller name.", :yellow
      exit(1)
    end
  end


  def base_name_without_controller
    name.gsub(/_?controllers?$/i, '')
  end

  def file_name_without_controller
    base_name_without_controller.underscore
  end

  def protected_stimulus_controller_names
    %w[
      dropdown
      clipboard
      theme
      mobile-sidebar
      sdk-integration
    ]
  end

  def insert_into_index_ts(controller_name, class_name)
    index_path = "app/javascript/controllers/index.ts"

    import_line = "import #{class_name} from \"./#{controller_name}_controller\""

    register_line = "application.register(\"#{controller_name.dasherize}\", #{class_name})"

    if File.exist?(index_path)
      inject_into_file index_path, "#{import_line}\n", after: /import.*_controller"\n(?=\n)/

      inject_into_file index_path, "#{register_line}\n", after: /application\.register\(.*\)\n(?=\n)/
    else
      say "⚠️  Warning: #{index_path} not found. Please add the import and registration manually:", :yellow
      say "Import: #{import_line}", :yellow
      say "Register: #{register_line}", :yellow
    end
  end
end
