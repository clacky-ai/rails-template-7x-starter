require 'rails_helper'

RSpec.describe 'Simple Stimulus Validator', type: :system do
  let(:controllers_dir) { Rails.root.join('app/javascript/controllers') }
  let(:views_dir) { Rails.root.join('app/views') }

  let(:controller_data) do
    data = {}

    Dir.glob(controllers_dir.join('*_controller.ts')).each do |file|
      controller_name = File.basename(file, '.ts').gsub('_controller', '').gsub('_', '-')
      content = File.read(file)

      targets = []
      if match = content.match(/static targets\s*=\s*\[(.*?)\]/m)
        targets = match[1].scan(/["']([^"']+)["']/).flatten
      end

      methods = []
      content.scan(/^\s*(?:async\s+)?(\w+)\s*\([^)]*\)\s*:\s*[\w<>]*\s*\{/) do |match|
        method_name = match[0]
        unless %w[connect disconnect constructor].include?(method_name)
          methods << method_name
        end
      end

      data[controller_name] = {
        targets: targets,
        methods: methods,
        file: file
      }
    end

    data
  end


  let(:view_files) do
    Dir.glob(views_dir.join('**/*.html.erb')).reject do |file|
      file.include?('shared/demo.html.erb')
    end
  end

  let(:partial_parent_map) do
    map = {}

    view_files.each do |view_file|
      content = File.read(view_file)
      relative_path = view_file.sub(Rails.root.to_s + '/', '')

      content.scan(/render\s+['"]([^'"]+)['"]/) do |match|
        partial_name = match[0]

        if partial_name.include?('/')
          # shared/admin/header -> app/views/shared/admin/_header.html.erb
          partial_path = "app/views/#{partial_name.gsub(/([^\/]+)$/, '_\1')}.html.erb"
        else
          # header -> app/views/current_dir/_header.html.erb
          current_dir = File.dirname(relative_path)
          partial_path = "#{current_dir}/_#{partial_name}.html.erb"
        end

        map[partial_path] ||= []
        map[partial_path] << relative_path
      end
    end

    map
  end

  def get_controllers_from_parents(partial_path)
    controllers = []

    parent_files = partial_parent_map[partial_path] || []
    parent_files.each do |parent_file|
      parent_content = File.read(Rails.root.join(parent_file))
      parent_doc = Nokogiri::HTML::DocumentFragment.parse(parent_content)

      parent_doc.css('[data-controller]').each do |element|
        element['data-controller'].split(/\s+/).each do |controller|
          controllers << controller.strip
        end
      end

      if parent_file.include?('_')
        controllers.concat(get_controllers_from_parents(parent_file))
      end
    end

    controllers.uniq
  end

  describe 'Core Validation: Targets and Actions' do
    it 'validates that controller targets exist in HTML and actions have methods' do
      target_errors = []
      action_errors = []
      scope_errors = []
      registration_errors = []

      view_files.each do |view_file|
        content = File.read(view_file)
        relative_path = view_file.sub(Rails.root.to_s + '/', '')

        doc = Nokogiri::HTML::DocumentFragment.parse(content)

        doc.css('[data-controller]').each do |controller_element|
          controllers = controller_element['data-controller'].split(/\s+/)

          controllers.each do |controller_name|
            controller_name = controller_name.strip

            # Check if controller exists
            unless controller_data.key?(controller_name)
              registration_errors << {
                controller: controller_name,
                file: relative_path,
                suggestion: "Create controller file: rails generate stimulus_controller #{controller_name.gsub('-', '_')}"
              }
              next # Skip further validation if controller doesn't exist
            end

            controller_data[controller_name][:targets].each do |target|
              target_found = false

              target_selector = "[data-#{controller_name}-target*='#{target}']"
              target_found = controller_element.css(target_selector).any?

              unless target_found
                rails_target_key = "#{controller_name.gsub('-', '_')}_target"
                rails_pattern = /data:\s*\{[^}]*#{Regexp.escape(rails_target_key)}:\s*["']#{Regexp.escape(target)}["'][^}]*\}/

                if controller_element.to_html.match?(rails_pattern)
                  target_found = true
                end
              end

              unless target_found
                erb_pattern = /data:\s*\{\s*#{Regexp.escape(controller_name.gsub('-', '_'))}_target:\s*["']#{Regexp.escape(target)}["']\s*\}/
                if content.match?(erb_pattern)
                  target_found = true
                end
              end

              unless target_found
                controller_start = content.index(%Q{data-controller="#{controller_name}"})
                if controller_start
                  content_after_controller = content[controller_start..-1]

                  controller_section = content_after_controller

                  target_pattern = /#{Regexp.escape(controller_name.gsub('-', '_'))}_target:\s*["']#{Regexp.escape(target)}["']/
                  if controller_section.match?(target_pattern)
                    target_found = true
                  end
                end
              end

              unless target_found
                target_errors << {
                  controller: controller_name,
                  target: target,
                  file: relative_path,
                  suggestion: "Add <div data-#{controller_name}-target=\"#{target}\">...</div> within controller scope"
                }
              end
            end
          end
        end

        doc.css('[data-action]').each do |action_element|
          actions = action_element['data-action'].split(/\s+/)

          actions.each do |action|
            if match = action.match(/^(?:(\w+)->)?(\w+(?:-\w+)*)#(\w+)(?:@\w+)?$/)
              event, controller_name, method_name = match[1], match[2], match[3]

              controller_scope = action_element.ancestors.css("[data-controller*='#{controller_name}']").first ||
                               (action_element['data-controller']&.include?(controller_name) ? action_element : nil)

              if !controller_scope && relative_path.include?('_')
                parent_controllers = get_controllers_from_parents(relative_path)
                if parent_controllers.include?(controller_name)
                  controller_scope = true
                end
              end

              unless controller_scope
                if relative_path.include?('_')
                  suggestion = "Controller '#{controller_name}' should be defined in parent template or wrap with <div data-controller=\"#{controller_name}\">...</div>"
                else
                  suggestion = "Wrap with <div data-controller=\"#{controller_name}\">...</div>"
                end

                scope_errors << {
                  action: action,
                  controller: controller_name,
                  file: relative_path,
                  is_partial: relative_path.include?('_'),
                  parent_files: partial_parent_map[relative_path] || [],
                  suggestion: suggestion
                }
                next
              end

              if controller_data.key?(controller_name)
                # Check if method exists
                unless controller_data[controller_name][:methods].include?(method_name)
                  action_errors << {
                    action: action,
                    controller: controller_name,
                    method: method_name,
                    file: relative_path,
                    available_methods: controller_data[controller_name][:methods],
                    suggestion: "Add method '#{method_name}(): void { }' to #{controller_name} controller"
                  }
                end
              end
            end
          end
        end
      end

      # Remove duplicates from registration errors
      registration_errors = registration_errors.uniq { |error| [error[:controller], error[:file]] }

      total_errors = target_errors.length + action_errors.length + scope_errors.length + registration_errors.length

      puts "\n🔍 Simple Stimulus Validation Results:"
      puts "   📁 Scanned: #{view_files.length} views, #{controller_data.keys.length} controllers"

      if total_errors == 0
        puts "   ✅ All validations passed!"
      else
        puts "\n   ❌ Found #{total_errors} issue(s):"

        if registration_errors.any?
          puts "\n   📝 Missing Controllers (#{registration_errors.length}):"
          registration_errors.each do |error|
            puts "     • #{error[:controller]} controller not found in #{error[:file]}"
          end
        end

        if target_errors.any?
          puts "\n   🎯 Missing Targets (#{target_errors.length}):"
          target_errors.each do |error|
            puts "     • #{error[:controller]}:#{error[:target]} missing in #{error[:file]}"
          end
        end

        if scope_errors.any?
          puts "\n   🚨 Scope Errors (#{scope_errors.length}):"
          scope_errors.each do |error|
            if error[:is_partial] && error[:parent_files].any?
              puts "     • #{error[:action]} needs controller scope in #{error[:file]} (partial rendered in: #{error[:parent_files].join(', ')})"
            else
              puts "     • #{error[:action]} needs controller scope in #{error[:file]}"
            end
          end
        end

        if action_errors.any?
          puts "\n   ⚠️  Method Errors (#{action_errors.length}):"
          action_errors.each do |error|
            puts "     • #{error[:controller]}##{error[:method]} not found in #{error[:file]}"
          end
        end

        error_details = []

        registration_errors.each do |error|
          error_details << "Missing controller: #{error[:controller]} in #{error[:file]} - #{error[:suggestion]}"
        end

        target_errors.each do |error|
          error_details << "Missing target: #{error[:controller]}:#{error[:target]} in #{error[:file]} - #{error[:suggestion]}"
        end

        scope_errors.each do |error|
          error_details << "Scope error: #{error[:action]} in #{error[:file]} - #{error[:suggestion]}"
        end

        action_errors.each do |error|
          error_details << "Method error: #{error[:controller]}##{error[:method]} in #{error[:file]} - #{error[:suggestion]}"
        end

        expect(total_errors).to eq(0), "Stimulus validation failed:\n#{error_details.join("\n")}\n\nNote: The above results are from static code analysis. Suggestions are for reference only."
      end
    end
  end

  describe 'Controller Analysis' do
    it 'provides controller coverage statistics' do
      total_controllers = controller_data.keys.length
      used_controllers = []

      view_files.each do |view_file|
        content = File.read(view_file)
        controller_data.keys.each do |controller|
          if content.include?("data-controller") && content.match(/\b#{Regexp.escape(controller)}\b/)
            used_controllers << controller
          end
        end
      end

      used_controllers = used_controllers.uniq
      unused_count = total_controllers - used_controllers.length

      puts "\n📊 Controller Usage Statistics:"
      puts "   • Total controllers: #{total_controllers}"
      puts "   • Used in views: #{used_controllers.length}"
      puts "   • Unused: #{unused_count}"

      if unused_count > 0
        unused = controller_data.keys - used_controllers
        puts "   ⚠️  Unused controllers: #{unused.join(', ')}"
      end

      expect(controller_data).not_to be_empty
    end
  end

  describe 'Quick Fix Suggestions' do
    it 'generates actionable fix commands' do
      missing_controllers = []

      view_files.each do |view_file|
        content = File.read(view_file)
        doc = Nokogiri::HTML::DocumentFragment.parse(content)

        doc.css('[data-controller], [data-action]').each do |element|
          if controller_attr = element['data-controller']
            controller_attr.split(/\s+/).each do |controller|
              unless controller_data.key?(controller)
                missing_controllers << controller
              end
            end
          end

          if action_attr = element['data-action']
            action_attr.split(/\s+/).each do |action|
              if match = action.match(/^(?:\w+->)?(\w+(?:-\w+)*)#\w+/)
                controller = match[1]
                unless controller_data.key?(controller)
                  missing_controllers << controller
                end
              end
            end
          end
        end
      end

      missing_controllers = missing_controllers.uniq

      if missing_controllers.any?
        puts "\n🔧 Quick Fix Commands:"
        missing_controllers.each do |controller|
          puts "   rails generate stimulus_controller #{controller.gsub('-', '_')}"
        end
      end

      expect(missing_controllers).to be_kind_of(Array)
    end
  end
end
