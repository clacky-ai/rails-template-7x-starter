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

      values = []
      if match = content.match(/static values\s*=\s*\{([^}]*)\}/m)
        values_content = match[1]
        values = values_content.scan(/(\w+):\s*\w+/).map { |m| m[0] }
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
        values: values,
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

      content.scan(/render\s+(?:partial:\s*)?['"]([^'"]+)['"]/) do |match|
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

  def parse_action_string(action_string)
    return [] unless action_string

    actions = []

    # Split by whitespace, but be careful about complex action strings
    action_parts = action_string.scan(/\S+/)

    action_parts.each do |action|
      # Improved regex to handle more action formats
      if match = action.match(/^(?:(\w+(?:\.\w+)*)->)?(\w+(?:-\w+)*)#(\w+)(?:@\w+)?$/)
        event, controller_name, method_name = match[1], match[2], match[3]
        actions << {
          action: action,
          event: event,
          controller: controller_name,
          method: method_name
        }
      end
    end

    actions
  end

  def parse_erb_actions(content, relative_path)
    actions = []

    # Parse data: { action: "..." } syntax across multiple lines
    erb_action_pattern = /data:\s*\{[^}]*action:\s*["']([^"']+)["'][^}]*\}/m

    # Find all matches in the entire content
    content.scan(erb_action_pattern) do |match|
      action_value = match[0]

      # Find which line this action starts on by looking for the action value
      lines = content.split("\n")
      action_line_number = nil

      lines.each_with_index do |line, index|
        if line.include?(action_value)
          action_line_number = index + 1
          break
        end
      end

      action_line_number ||= 1 # fallback

      # Parse the action string which may contain multiple actions
      parsed_actions = parse_action_string(action_value)

      parsed_actions.each do |action_info|
        actions << {
          element: nil, # ERB actions don't have direct DOM elements
          action: action_info[:action],
          event: action_info[:event],
          controller: action_info[:controller],
          method: action_info[:method],
          source: 'erb',
          line_number: action_line_number,
          line_content: action_value
        }
      end
    end

    actions
  end

  def check_erb_action_scope(action_info, content, relative_path)
    controller_name = action_info[:controller]
    action_line = action_info[:line_number]

    # Find all controller definitions in the file
    controller_scopes = []
    lines = content.split("\n")

    lines.each_with_index do |line, index|
      line_num = index + 1

      # Check for data-controller attribute
      if line.match(/data-controller=["'][^"']*\b#{Regexp.escape(controller_name)}\b[^"']*["']/)
        # Find the scope boundaries for this controller
        scope_start = line_num
        scope_end = find_scope_end(lines, index)
        controller_scopes << { start: scope_start, end: scope_end, line: line.strip }

      end
    end

    # Check if action line is within any controller scope
    in_scope = controller_scopes.any? do |scope|
      action_line >= scope[:start] && action_line <= scope[:end]
    end

    in_scope
  end

  def find_scope_end(lines, start_index)
    # Find the opening tag that contains data-controller
    start_line = lines[start_index]

    # Look for the opening tag in the current line or previous line
    opening_tag_line = nil
    tag_name = nil

    # Check current line and previous line for opening tag
    [start_index - 1, start_index].each do |line_idx|
      next if line_idx < 0
      line = lines[line_idx]
      if match = line.match(/<(\w+)(?:\s[^>]*)?(?:\s+data-controller|\s+id=)/)
        tag_name = match[1]
        opening_tag_line = line_idx
        break
      end
    end

    return lines.length unless tag_name

    # Count nested tags to find the matching closing tag
    depth = 0
    tag_found = false

    (opening_tag_line...lines.length).each do |i|
      line = lines[i]

      # Look for opening tags
      line.scan(/<#{tag_name}(?:\s|>)/) do
        depth += 1
        tag_found = true
      end

      # Look for closing tags
      line.scan(/<\/#{tag_name}>/) do
        depth -= 1
        if depth == 0 && tag_found
          return i + 1
        end
      end
    end

    # If no matching closing tag found, assume scope extends to end of file
    lines.length
  end

  describe 'Core Validation: Targets and Actions' do
    it 'validates that controller targets exist in HTML and actions have methods' do
      target_errors = []
      action_errors = []
      scope_errors = []
      registration_errors = []
      value_errors = []

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

            # Check for missing or incorrectly formatted values
            controller_data[controller_name][:values].each do |value_name|
              kebab_value_name = value_name.gsub(/([a-z])([A-Z])/, '\1-\2').downcase
              expected_attr = "data-#{controller_name}-#{kebab_value_name}-value"

              if !controller_element.has_attribute?(expected_attr)
                # Check for common mistakes in ERB context
                common_mistakes = [
                  "data-#{value_name}",
                  "data-#{controller_name}-#{value_name}",
                  "data-#{controller_name}-#{kebab_value_name}",
                  "data-#{value_name}-value"
                ]

                # Filter out standard Stimulus attributes
                stimulus_standard_attrs = %w[data-controller data-action data-target]
                common_mistakes = common_mistakes.reject { |attr|
                  stimulus_standard_attrs.any? { |std_attr| attr.start_with?(std_attr) }
                }

                found_mistakes = common_mistakes.select { |attr|
                  controller_element.has_attribute?(attr) || content.include?(attr)
                }

                if found_mistakes.any?
                  value_errors << {
                    controller: controller_name,
                    value: value_name,
                    file: relative_path,
                    expected: expected_attr,
                    found: found_mistakes.first,
                    suggestion: "Change '#{found_mistakes.first}' to '#{expected_attr}'"
                  }
                else
                  value_errors << {
                    controller: controller_name,
                    value: value_name,
                    file: relative_path,
                    expected: expected_attr,
                    found: nil,
                    suggestion: "Add #{expected_attr}=\"...\" to controller element"
                  }
                end
              end
            end
          end
        end

        # Parse both HTML data-action attributes and ERB data: { action: } syntax
        all_actions = []

        # Parse HTML data-action attributes
        doc.css('[data-action]').each do |action_element|
          action_value = action_element['data-action']
          parsed_actions = parse_action_string(action_value)
          parsed_actions.each do |action_info|
            all_actions << {
              element: action_element,
              action: action_info[:action],
              event: action_info[:event],
              controller: action_info[:controller],
              method: action_info[:method]
            }
          end
        end

        # Parse ERB data: { action: } syntax
        erb_actions = parse_erb_actions(content, relative_path)
        erb_actions.each do |action_info|
          all_actions << action_info
        end

        all_actions.each do |action_info|
          action_element = action_info[:element]
          controller_name = action_info[:controller]
          method_name = action_info[:method]
          action = action_info[:action]
          source = action_info[:source]

          # For ERB actions, check if controller scope actually includes the action
          if source == 'erb' || source == 'erb_snake_case'
            controller_scope = false

            # Use proper scope checking for ERB actions
            controller_scope = check_erb_action_scope(action_info, content, relative_path)

            # Check parent files for partials
            if !controller_scope && relative_path.include?('_')
              parent_controllers = get_controllers_from_parents(relative_path)
              if parent_controllers.include?(controller_name)
                controller_scope = true
              end
            end
          else
            # For HTML data-action attributes
            controller_scope = action_element.ancestors.css("[data-controller*='#{controller_name}']").first ||
                             (action_element['data-controller']&.include?(controller_name) ? action_element : nil)

            if !controller_scope && relative_path.include?('_')
              parent_controllers = get_controllers_from_parents(relative_path)
              if parent_controllers.include?(controller_name)
                controller_scope = true
              end
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
              suggestion: suggestion,
              source: source
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
                suggestion: "Add method '#{method_name}(): void { }' to #{controller_name} controller",
                source: source
              }
            end
          end
        end
      end

      # Remove duplicates from registration errors
      registration_errors = registration_errors.uniq { |error| [error[:controller], error[:file]] }

      total_errors = target_errors.length + action_errors.length + scope_errors.length + registration_errors.length + value_errors.length

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

        if value_errors.any?
          puts "\n   📋 Value Errors (#{value_errors.length}):"
          value_errors.each do |error|
            if error[:found]
              puts "     • #{error[:controller]}:#{error[:value]} incorrect format '#{error[:found]}' in #{error[:file]}, expected '#{error[:expected]}'"
            else
              puts "     • #{error[:controller]}:#{error[:value]} missing in #{error[:file]}"
            end
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

        value_errors.each do |error|
          error_details << "Value error: #{error[:controller]}:#{error[:value]} in #{error[:file]} - #{error[:suggestion]}"
        end

        scope_errors.each do |error|
          error_details << "Scope error: #{error[:action]} in #{error[:file]} - #{error[:suggestion]}"
        end

        action_errors.each do |error|
          error_details << "Method error: #{error[:controller]}##{error[:method]} in #{error[:file]} - #{error[:suggestion]}"
        end

        expect(total_errors).to eq(0), "Stimulus validation failed:\n#{error_details.join("\n")}"
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
