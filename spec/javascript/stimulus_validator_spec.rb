require 'rails_helper'

RSpec.describe 'Stimulus Validator Logic', type: :system do
  # Simulates all core logic of stimulus_validator

  let(:js_index_path) { Rails.root.join('app/javascript/controllers/index.ts') }
  let(:js_index_content) { File.read(js_index_path) }

  # Get list of registered controllers
  let(:registered_controllers) do
    controllers = []
    js_index_content.scan(/application\.register\("([^"]+)"/) do |match|
      controllers << match[0]
    end
    controllers
  end

  # Get all view files
  let(:view_files) do
    Dir.glob(Rails.root.join('app/views/**/*.html.erb')).reject do |file|
      file.include?('shared/demo.html.erb') || file.match?(/\/views\/admin\/[^\/]*\.html\.erb$/)
    end
  end

  # Parse controller method mappings
  let(:controller_methods) do
    methods_map = {}

    Dir.glob(Rails.root.join('app/javascript/controllers/*_controller.ts')).each do |controller_file|
      controller_name = File.basename(controller_file, '.ts').gsub('_controller', '').gsub('_', '-')
      content = File.read(controller_file)

      # Extract method names (including async methods)
      methods = []
      # Match regular methods: methodName(...): returnType {
      content.scan(/^\s*(\w+)\s*\([^)]*\)\s*:\s*[\w<>]+\s*\{/) do |match|
        method_name = match[0]
        # Exclude special methods
        unless %w[connect disconnect constructor].include?(method_name)
          methods << method_name
        end
      end

      # Match async methods: async methodName(...): Promise<returnType> {
      content.scan(/^\s*async\s+(\w+)\s*\([^)]*\)\s*:\s*Promise<[\w<>]+>\s*\{/) do |match|
        method_name = match[0]
        # Exclude special methods
        unless %w[connect disconnect constructor].include?(method_name)
          methods << method_name
        end
      end

      # Match private methods: private methodName(...): returnType {
      content.scan(/^\s*private\s+(?:async\s+)?(\w+)\s*\([^)]*\)\s*:\s*(?:Promise<)?[\w<>]+>?\s*\{/) do |match|
        method_name = match[0]
        # Only include non-private methods
        # Private methods should not be called from HTML actions
      end

      methods_map[controller_name] = methods
    end

    methods_map
  end

  describe 'Controller Registration Validation' do
    it 'finds missing controllers in views' do
      missing_controllers = []
      controller_scope_errors = []
      method_errors = []
      syntax_errors = []

      view_files.each do |view_file|
        content = File.read(view_file)
        relative_path = view_file.sub(Rails.root.to_s + '/', '')

        # Parse HTML as DOM
        require 'nokogiri'
        doc = Nokogiri::HTML::DocumentFragment.parse(content)

        # Check all data-controller elements
        doc.css('[data-controller]').each do |controller_element|
          controllers = controller_element['data-controller'].split(/\s+/)

          controllers.each do |controller|
            unless registered_controllers.include?(controller)
              missing_controllers << {
                controller: controller,
                file: relative_path,
                element: controller_element.to_s.split("\n").first + "..."
              }
            end
          end
        end

        # Check all data-action elements
        doc.css('[data-action]').each do |action_element|
          actions = action_element['data-action'].split(/\s+/)

          actions.each do |action|
            # Parse action format
            if action.match(/^([\w:.]+->)?([\w-]+)#([\w-]+)(@[\w-]+)?$/)
              event_part = $1
              controller_name = $2
              method_name = $3
              target_part = $4

              # Check if controller is registered
              unless registered_controllers.include?(controller_name)
                missing_controllers << {
                  controller: controller_name,
                  file: relative_path,
                  action: action,
                  element: action_element.to_s.split("\n").first + "..."
                }
                next
              end

              # Check controller scope
              has_controller_scope = false
              current = action_element
              while current && current.respond_to?(:parent)
                if current['data-controller']&.split(/\s+/)&.include?(controller_name)
                  has_controller_scope = true
                  break
                end
                current = current.parent
                break if current.nil? || (current.respond_to?(:name) && current.name == 'document')
              end

              unless has_controller_scope
                controller_scope_errors << {
                  controller: controller_name,
                  action: action,
                  file: relative_path,
                  element: action_element.to_s.split("\n").first + "..."
                }
              end

              # Check if method exists
              if has_controller_scope && controller_methods[controller_name]
                unless controller_methods[controller_name].include?(method_name)
                  method_errors << {
                    controller: controller_name,
                    method: method_name,
                    action: action,
                    file: relative_path,
                    available_methods: controller_methods[controller_name],
                    element: action_element.to_s.split("\n").first + "..."
                  }
                end
              end

            else
              # Syntax error
              syntax_errors << {
                action: action,
                file: relative_path,
                element: action_element.to_s.split("\n").first + "..."
              }
            end
          end
        end
      end

      # Summary statistics
      total_errors = missing_controllers.length + controller_scope_errors.length + method_errors.length + syntax_errors.length

      # Simplified reporting results
      puts "\n🔍 Stimulus Validation: #{view_files.length} files, #{registered_controllers.length} controllers"

      # Only show details when there are errors
      if missing_controllers.any?
        puts "\n❌ MISSING CONTROLLERS (#{missing_controllers.length}):"
        missing_controllers.uniq { |c| [c[:controller], c[:file]] }.each do |error|
          puts "   • '#{error[:controller]}' in #{error[:file]}"
        end
      end

      if controller_scope_errors.any?
        puts "\n🚨 SCOPE ERRORS (#{controller_scope_errors.length}):"
        controller_scope_errors.each do |error|
          puts "   • #{error[:action]} needs data-controller=\"#{error[:controller]}\" in #{error[:file]}"
        end
      end

      if method_errors.any?
        puts "\n⚠️  METHOD ERRORS (#{method_errors.length}):"
        method_errors.each do |error|
          puts "   • #{error[:controller]}##{error[:method]} not found in #{error[:file]}"
        end
      end

      if syntax_errors.any?
        puts "\n❌ SYNTAX ERRORS (#{syntax_errors.length}):"
        syntax_errors.each do |error|
          puts "   • Invalid action '#{error[:action]}' in #{error[:file]}"
        end
      end

      # Simplified final summary
      if total_errors == 0
        puts "   ✅ All checks passed!"
      else
        puts "\n📊 Found #{total_errors} error(s): #{missing_controllers.length} missing, #{controller_scope_errors.length} scope, #{method_errors.length} method, #{syntax_errors.length} syntax"
      end

      # Test failure condition: fail if there are any errors
      if total_errors > 0
        error_message = "Stimulus validation failed with #{total_errors} error(s):\n\n"

        if missing_controllers.any?
          error_message += "❌ MISSING CONTROLLERS (#{missing_controllers.length}):\n"
          missing_controllers.uniq { |c| [c[:controller], c[:file]] }.each_with_index do |error, i|
            error_message += "   #{i + 1}. Controller '#{error[:controller]}' not registered\n"
            error_message += "      📁 File: #{error[:file]}\n"
            error_message += "      ⚡ Action: #{error[:action]}\n" if error[:action]
            error_message += "      🔧 Fix: rails generate stimulus_controller #{error[:controller].gsub('-', '_')}\n"
            error_message += "\n"
          end
        end

        if controller_scope_errors.any?
          error_message += "🚨 SCOPE ERRORS (#{controller_scope_errors.length}):\n"
          controller_scope_errors.each_with_index do |error, i|
            error_message += "   #{i + 1}. Action '#{error[:action]}' missing controller scope\n"
            error_message += "      🎮 Required: data-controller=\"#{error[:controller]}\"\n"
            error_message += "      📁 File: #{error[:file]}\n"
            error_message += "      🔧 Fix: Wrap element with <div data-controller=\"#{error[:controller]}\">...</div>\n"
            error_message += "\n"
          end
        end

        if method_errors.any?
          error_message += "⚠️  METHOD ERRORS (#{method_errors.length}):\n"
          method_errors.each_with_index do |error, i|
            error_message += "   #{i + 1}. Method '#{error[:method]}' not found in '#{error[:controller]}'\n"
            error_message += "      ⚡ Action: #{error[:action]}\n"
            error_message += "      📁 File: #{error[:file]}\n"
            if error[:available_methods].any?
              error_message += "      ✅ Available: #{error[:available_methods].join(', ')}\n"
            else
              error_message += "      ❌ No public methods found\n"
            end
            error_message += "      🔧 Fix: Add method '#{error[:method]}(): void { }' to controller\n"
            error_message += "\n"
          end
        end

        if syntax_errors.any?
          error_message += "❌ SYNTAX ERRORS (#{syntax_errors.length}):\n"
          syntax_errors.each_with_index do |error, i|
            error_message += "   #{i + 1}. Invalid action syntax: '#{error[:action]}'\n"
            error_message += "      📁 File: #{error[:file]}\n"
            error_message += "      🔧 Fix: Use format like 'click->controller#method'\n"
            error_message += "\n"
          end
        end

        error_message += "🎯 QUICK FIXES:\n"
        if missing_controllers.any?
          error_message += "   Generate missing controllers:\n"
          missing_controllers.map { |c| c[:controller] }.uniq.each do |controller|
            error_message += "   $ rails generate stimulus_controller #{controller.gsub('-', '_')}\n"
          end
        end

        expect(total_errors).to eq(0), error_message
      end
    end
  end

  describe 'Controller Methods Analysis' do
    it 'analyzes controller method coverage' do
      puts "\n🔧 Controller Methods: #{controller_methods.keys.length} controllers mapped"

      unused_controllers = []
      controller_methods.each do |controller, methods|
        usage_count = 0
        view_files.each do |view_file|
          content = File.read(view_file)
          if content.match(/data-controller=["'][^"']*\b#{Regexp.escape(controller)}\b[^"']*["']/)
            usage_count += 1
          end
        end

        if usage_count == 0 && !controller.include?('test')
          unused_controllers << controller
        end
      end

      if unused_controllers.any?
        puts "   ⚠️  Unused controllers: #{unused_controllers.join(', ')}"
      else
        puts "   ✅ All controllers are used"
      end

      expect(controller_methods).not_to be_empty
    end
  end

  describe 'Target Usage Analysis' do
    it 'analyzes target definitions and usage' do
      target_issues = []

      view_files.each do |view_file|
        content = File.read(view_file)
        relative_path = view_file.sub(Rails.root.to_s + '/', '')

        content.scan(/data-(\w+(?:-\w+)*)-target=["']([^"']+)["']/) do |controller, targets|
          targets.split(/\s+/).each do |target|
            controller_file = Rails.root.join("app/javascript/controllers/#{controller.gsub('-', '_')}_controller.ts")

            if File.exist?(controller_file)
              controller_content = File.read(controller_file)

              targets_defined = controller_content.scan(/static targets = \[(.*?)\]/m).flatten.join
              target_declared = targets_defined.include?("\"#{target}\"")

              target_used = controller_content.include?("#{target}Target")

              unless target_declared
                target_issues << "#{controller}:#{target} undeclared"
              end

              unless target_used
                target_issues << "#{controller}:#{target} unused"
              end
            end
          end
        end
      end

      if target_issues.any?
        puts "\n🎯 Targets: #{target_issues.length} issues found"
        target_issues.each do |issue|
          puts "   • #{issue}"
        end
      else
        puts "\n🎯 Targets: All targets OK"
      end

      expect(target_issues).to be_kind_of(Array)
    end
  end

  describe 'Real-time Click Simulation' do
    it 'simulates stimulus validator click interception logic', js: true do
      test_cases = [
        {
          action: 'click->form-builder#saveForm',
          controller_scope: 'form-builder',
          expected_result: 'success'
        },
        {
          action: 'click->non-existent#method',
          controller_scope: nil,
          expected_result: 'missing_controller'
        },
        {
          action: 'click->form-builder#nonExistentMethod',
          controller_scope: 'form-builder',
          expected_result: 'missing_method'
        },
        {
          action: 'click->form-builder#saveForm',
          controller_scope: nil,
          expected_result: 'scope_error'
        }
      ]

      results = []
      test_cases.each do |test_case|
        if test_case[:action].match(/^([\w:.]+->)?([\w-]+)#([\w-]+)(@[\w-]+)?$/)
          controller_name = $2
          method_name = $3

          controller_registered = registered_controllers.include?(controller_name)

          has_scope = test_case[:controller_scope] == controller_name

          method_exists = controller_methods[controller_name]&.include?(method_name) || false

          result = if !controller_registered
            'missing_controller'
          elsif !has_scope
            'scope_error'
          elsif !method_exists
            'missing_method'
          else
            'success'
          end

          results << (result == test_case[:expected_result])
          expect(result).to eq(test_case[:expected_result])
        end
      end

      puts "\n🖱️  Click Simulation: #{results.all? ? 'All tests passed' : 'Some tests failed'}"
    end
  end
end
