class StimulusControllerGenerator < Rails::Generators::NamedBase
  source_root File.expand_path('templates', __dir__)

  desc 'Generate a Stimulus controller with TypeScript support'

  
  def create_stimulus_controller
    check_name_validity
    
    controller_name = file_name_without_controller
    class_name = "#{controller_name.camelize}Controller"
    
    template 'controller.ts.erb', "app/javascript/controllers/#{controller_name}_controller.ts"
    
    insert_into_index_ts(controller_name, class_name)
    
    say "✅ Stimulus controller '#{controller_name}' created successfully!", :green
    say "📁 Controller file: app/javascript/controllers/#{controller_name}_controller.ts", :blue
    say "📄 Added to: app/javascript/controllers/index.ts", :blue
  end

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
