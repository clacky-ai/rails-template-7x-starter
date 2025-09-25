require 'rails_helper'

RSpec.describe 'Stimulus JavaScript Controllers Consistency' do
  let(:js_index_path) { Rails.root.join('app/javascript/controllers/index.ts') }
  let(:js_index_content) { File.read(js_index_path) }
  
  let(:registered_controllers) do
    controllers = []
    # Extract registered controllers from application.register calls
    js_index_content.scan(/application\.register\("([^"]+)"/) do |match|
      controllers << match[0]
    end
    controllers
  end

  let(:imported_controllers) do
    controllers = []
    # Extract imported controller names and their expected registration names
    js_index_content.scan(/import\s+(\w+)Controller\s+from\s+"\.\/(\w+)_controller"/) do |match|
      class_name = match[0]
      file_name = match[1]
      
      # Convert CamelCase to kebab-case for expected registration name
      expected_name = class_name.gsub(/([A-Z])/, '-\1').downcase.sub(/^-/, '')
      
      controllers << {
        class_name: "#{class_name}Controller",
        file_name: "#{file_name}_controller",
        expected_registration: expected_name,
        actual_registrations: []
      }
    end
    
    # Find actual registrations for each controller
    controllers.each do |controller|
      js_index_content.scan(/application\.register\("([^"]+)",\s*#{controller[:class_name]}\)/) do |match|
        controller[:actual_registrations] << match[0]
      end
    end
    
    controllers
  end

  describe 'Controller Import and Registration Consistency' do
    it 'has all imported controllers registered' do
      unregistered_controllers = imported_controllers.select { |c| c[:actual_registrations].empty? }
      
      if unregistered_controllers.any?
        error_msg = "Imported controllers that are not registered:\n"
        unregistered_controllers.each do |controller|
          error_msg += "  - #{controller[:class_name]} (expected registration: '#{controller[:expected_registration]}')\n"
        end
        error_msg += "\nAdd these registrations to #{js_index_path}:\n"
        unregistered_controllers.each do |controller|
          error_msg += "  application.register(\"#{controller[:expected_registration]}\", #{controller[:class_name]})\n"
        end
      end
      
      expect(unregistered_controllers).to be_empty, error_msg
    end

    it 'has correct naming conventions for registrations' do
      naming_issues = []
      
      imported_controllers.each do |controller|
        next if controller[:actual_registrations].empty?
        
        controller[:actual_registrations].each do |registration|
          unless registration == controller[:expected_registration]
            naming_issues << {
              controller: controller[:class_name],
              expected: controller[:expected_registration],
              actual: registration
            }
          end
        end
      end
      
      if naming_issues.any?
        error_msg = "Controller registration naming issues:\n"
        naming_issues.each do |issue|
          error_msg += "  - #{issue[:controller]}: registered as '#{issue[:actual]}', expected '#{issue[:expected]}'\n"
        end
        error_msg += "\nFix the registrations in #{js_index_path}\n"
      end
      
      expect(naming_issues).to be_empty, error_msg
    end

    it 'has all registered controllers imported' do
      registered_but_not_imported = registered_controllers.reject do |reg_name|
        imported_controllers.any? { |imp| imp[:actual_registrations].include?(reg_name) }
      end
      
      if registered_but_not_imported.any?
        error_msg = "Controllers registered but not imported:\n"
        registered_but_not_imported.each do |controller|
          # Convert kebab-case to CamelCase for class name suggestion
          class_name = controller.split('-').map(&:capitalize).join + 'Controller'
          file_name = controller.gsub('-', '_') + '_controller'
          
          error_msg += "  - '#{controller}' (add: import #{class_name} from \"./#{file_name}\")\n"
        end
      end
      
      expect(registered_but_not_imported).to be_empty, error_msg
    end
  end

  describe 'Controller File Existence' do
    it 'has corresponding TypeScript files for all imported controllers' do
      missing_files = []
      
      imported_controllers.each do |controller|
        file_path = Rails.root.join("app/javascript/controllers/#{controller[:file_name]}.ts")
        unless File.exist?(file_path)
          missing_files << {
            controller: controller[:class_name],
            expected_file: "app/javascript/controllers/#{controller[:file_name]}.ts"
          }
        end
      end
      
      if missing_files.any?
        error_msg = "Missing controller files:\n"
        missing_files.each do |missing|
          error_msg += "  - #{missing[:expected_file]} for #{missing[:controller]}\n"
        end
        error_msg += "\nGenerate missing controllers with:\n"
        missing_files.each do |missing|
          controller_name = missing[:controller].sub(/Controller$/, '').gsub(/([A-Z])/, '_\1').downcase.sub(/^_/, '')
          error_msg += "  rails generate stimulus_controller #{controller_name}\n"
        end
      end
      
      expect(missing_files).to be_empty, error_msg
    end
  end

  describe 'Stimulus Controller Registry Info' do
    it 'displays current controller status for debugging' do
      puts "\n🔧 Stimulus Controller Registry Analysis:"
      puts "   Total imported: #{imported_controllers.length}"
      puts "   Total registered: #{registered_controllers.length}"
      
      puts "\n📝 Controller Details:"
      imported_controllers.each do |controller|
        status = controller[:actual_registrations].any? ? "✓" : "✗"
        registrations = controller[:actual_registrations].any? ? 
          controller[:actual_registrations].join(', ') : 
          "NOT REGISTERED"
        
        puts "   #{status} #{controller[:class_name]} → [#{registrations}]"
      end
      
      # Always pass - this is just informational
      expect(true).to be true
    end
  end
end
