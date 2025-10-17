require 'rails_helper'
require 'parser/current'

# ERB AST Parser for Stimulus validation
class ErbAstParser
  def initialize(content)
    @content = content
    @erb_blocks = extract_erb_blocks
  end

  # Extract all ERB blocks from content
  def extract_erb_blocks
    blocks = []

    # Extract <%= %> blocks (output)
    @content.scan(/<%=\s*(.*?)\s*%>/m) do |match|
      blocks << {
        type: :output,
        code: match[0].strip,
        full_match: $&,
        position: $~.offset(0)
      }
    end

    # Extract <% %> blocks (execution)
    @content.scan(/<%\s*(.*?)\s*%>/m) do |match|
      next if match[0].strip.start_with?('=') # Skip <%= blocks already captured
      blocks << {
        type: :execution,
        code: match[0].strip,
        full_match: $&,
        position: $~.offset(0)
      }
    end

    blocks = blocks.sort_by { |block| block[:position][0] }

    # Merge blocks that form complete Ruby structures
    merge_block_pairs(blocks)
  end

  # Merge ERB blocks that should be parsed together (e.g., form_with...do and end)
  def merge_block_pairs(blocks)
    merged = []
    skip_indices = Set.new

    blocks.each_with_index do |block, i|
      next if skip_indices.include?(i)

      code = block[:code]

      # Check if this block opens a Ruby block structure (do, do |...|, {, etc.)
      # and doesn't close it
      opens_block = code.match(/\b(do\s*(\|[^|]*\|)?)/) ||
                    code.match(/\{\s*(\|[^|]*\|)?/)

      # Check if the block has an unmatched 'do' by looking for standalone 'end' keyword
      has_unmatched_do = opens_block && !has_end_keyword?(code)

      if has_unmatched_do
        # Look for the matching end/} block using nesting level counting
        merged_code = code.dup
        j = i + 1
        nesting_level = 1  # Start with 1 for the initial unmatched 'do'

        # Find all blocks until nesting level reaches 0
        while j < blocks.length && nesting_level > 0
          next_block = blocks[j]
          next_code = next_block[:code]

          # Remove string literals to avoid counting 'do'/'end' inside strings
          code_without_strings = next_code.gsub(/'[^']*'|"[^"]*"/, '')

          # Count 'do' keywords (opens new nesting level)
          nesting_level += code_without_strings.scan(/\bdo\b/).length

          # Count 'end' keywords (closes nesting level)
          nesting_level -= code_without_strings.scan(/\bend\b/).length

          # Add a newline between merged blocks for proper Ruby syntax
          merged_code += "\n" + next_code
          skip_indices.add(j)

          j += 1
        end

        # Create merged block
        merged << {
          type: block[:type],
          code: merged_code,
          full_match: block[:full_match],
          position: block[:position],
          merged: true
        }
      else
        # Keep block as-is
        merged << block
      end
    end

    merged
  end

  # Find Stimulus targets in ERB blocks
  def find_stimulus_targets(controller_name, target_name)
    results = []

    @erb_blocks.each do |block|
      # Skip blocks that don't contain target-related keywords
      next unless should_parse_for_targets?(block[:code], controller_name, target_name)

      # Parse the code with smart preprocessing - fail fast on errors
      processed_code = preprocess_erb_code(block[:code])
      ast = Parser::CurrentRuby.parse(processed_code)
      target_matches = find_targets_in_ast(ast, controller_name, target_name)

      target_matches.each do |match|
        results << {
          block: block,
          match: match,
          line_number: calculate_line_number(block[:position][0])
        }
      end
    end

    results
  end

  # Find Stimulus actions in ERB blocks
  def find_stimulus_actions(controller_name = nil)
    results = []

    @erb_blocks.each do |block|
      # Skip blocks that don't contain action-related keywords
      next unless should_parse_for_actions?(block[:code])

      # Parse the code with smart preprocessing - fail fast on errors
      processed_code = preprocess_erb_code(block[:code])
      ast = Parser::CurrentRuby.parse(processed_code)
      action_matches = find_actions_in_ast(ast, controller_name)

      action_matches.each do |match|
        results << {
          block: block,
          match: match,
          line_number: calculate_line_number(block[:position][0])
        }
      end
    end

    results
  end

  # Find Stimulus values in ERB blocks
  def find_stimulus_values(controller_name, value_name)
    results = []

    @erb_blocks.each do |block|
      # Skip blocks that don't contain value-related keywords
      next unless should_parse_for_values?(block[:code], controller_name, value_name)

      # Parse the code with smart preprocessing - fail fast on errors
      processed_code = preprocess_erb_code(block[:code])
      ast = Parser::CurrentRuby.parse(processed_code)
      value_matches = find_values_in_ast(ast, controller_name, value_name)

      value_matches.each do |match|
        results << {
          block: block,
          match: match,
          line_number: calculate_line_number(block[:position][0])
        }
      end
    end

    results
  end

  private

  # Check if code has an unmatched 'end' keyword
  # Need to exclude 'end' inside strings (both single and double quoted)
  def has_end_keyword?(code)
    # Remove string literals to avoid matching 'end' inside strings
    # This handles both single and double quoted strings
    code_without_strings = code.gsub(/'[^']*'|"[^"]*"/, '')
    code_without_strings.match?(/\bend\b/)
  end

  # Check if ERB block should be parsed for targets
  def should_parse_for_targets?(code, controller_name, target_name)
    # Must contain 'data' and either 'target' or the specific target name
    return false unless code.include?('data')
    return true if code.include?('target') || code.include?(target_name)
    return true if code.include?(controller_name)
    false
  end

  # Check if ERB block should be parsed for actions
  def should_parse_for_actions?(code)
    # Must contain 'data' and 'action'
    code.include?('data') && code.include?('action')
  end

  # Check if ERB block should be parsed for values
  def should_parse_for_values?(code, controller_name, value_name)
    # Must contain 'data' and either 'value' or the specific value name
    return false unless code.include?('data')
    return true if code.include?('value') || code.include?(value_name)
    return true if code.include?(controller_name)
    false
  end

  # Preprocess ERB code to make it more parseable
  def preprocess_erb_code(code)
    # Skip blocks that don't contain Stimulus-related keywords
    stimulus_keywords = ['data', 'controller', 'target', 'action', 'value']
    return code unless stimulus_keywords.any? { |keyword| code.include?(keyword) }

    # Skip preprocessing for simple expressions that are likely to parse correctly
    return code if code.strip.match?(/^\w+\s*\(.*\)$/) || code.strip.match?(/^[\w\.\[\]]+$/)

    # Handle common ERB patterns that cause parsing issues
    processed = code.dup

    # Skip blocks that are clearly control structures (if, unless, case, etc.)
    return code if processed.strip.match?(/^(if|unless|case|when|else|elsif|end|do|while|for|begin|rescue|ensure)\b/)

    # Skip blocks that look like method definitions or class definitions
    return code if processed.strip.match?(/^(def|class|module)\b/)

    # Skip blocks that are just variable assignments or simple expressions
    return code if processed.strip.match?(/^@?\w+\s*[=\[]/) || processed.strip.match?(/^[\w\.\[\]"']+$/)

    # For method calls with blocks, try to make them parseable
    unless has_end_keyword?(processed)
      if processed.include?(' do |')
        processed += "\nend"
      elsif processed.include?(' do') && !processed.include?('|')
        processed += "\nend"
      end
    end

    # Handle incomplete hash literals
    if processed.count('{') > processed.count('}')
      processed += ' }' * (processed.count('{') - processed.count('}'))
    end

    # Handle incomplete array literals
    if processed.count('[') > processed.count(']')
      processed += ' ]' * (processed.count('[') - processed.count(']'))
    end

    # Handle incomplete parentheses
    if processed.count('(') > processed.count(')')
      processed += ' )' * (processed.count('(') - processed.count(')'))
    end

    processed
  end

  def find_targets_in_ast(node, controller_name, target_name)
    return [] unless node

    matches = []

    case node.type
    when :hash
      matches.concat(find_targets_in_hash(node, controller_name, target_name))
    when :send
      matches.concat(find_targets_in_method_call(node, controller_name, target_name))
    end

    # Recursively search child nodes
    if node.respond_to?(:children)
      node.children.each do |child|
        next unless child.is_a?(Parser::AST::Node)
        matches.concat(find_targets_in_ast(child, controller_name, target_name))
      end
    end

    matches
  end

  def find_targets_in_hash(hash_node, controller_name, target_name)
    matches = []

    # Process hash pairs - in AST, each child is a :pair node
    hash_node.children.each do |pair_node|
      next unless pair_node.type == :pair

      key_node = pair_node.children[0]
      value_node = pair_node.children[1]

      next unless key_node && value_node

      # Handle string keys: "controller-target" => "target"
      if key_node.type == :str && value_node.type == :str
        key_str = key_node.children[0]
        value_str = value_node.children[0]

        if key_str == "#{controller_name}-target" && value_str == target_name
          matches << {
            type: :hash_string_key,
            controller: controller_name,
            target: target_name,
            key_node: key_node,
            value_node: value_node
          }
        end
      end

      # Handle symbol keys: controller_target: "target" or "controller-target": "target"
      if key_node.type == :sym && value_node.type == :str
        key_sym = key_node.children[0]
        value_str = value_node.children[0]

        # Support both formats: underscore and hyphen
        expected_key_underscore = "#{controller_name.gsub('-', '_')}_target"
        expected_key_hyphen = "#{controller_name}-target"

        if (key_sym.to_s == expected_key_underscore || key_sym.to_s == expected_key_hyphen) && value_str == target_name
          matches << {
            type: :hash_symbol_key,
            controller: controller_name,
            target: target_name,
            key_node: key_node,
            value_node: value_node
          }
        end
      end
    end

    matches
  end

  def find_targets_in_method_call(send_node, controller_name, target_name)
    matches = []

    # Look for method calls that might contain data attributes
    # This handles cases like: data: { ... }
    if send_node.children.length >= 2
      method_name = send_node.children[1]

      # Check if this is a method call with hash arguments
      send_node.children[2..-1].each do |arg|
        next unless arg.is_a?(Parser::AST::Node) && arg.type == :hash
        matches.concat(find_targets_in_hash(arg, controller_name, target_name))
      end
    end

    matches
  end

  def find_actions_in_ast(node, controller_name)
    return [] unless node

    matches = []

    case node.type
    when :hash
      matches.concat(find_actions_in_hash(node, controller_name))
    when :send
      matches.concat(find_actions_in_method_call(node, controller_name))
    end

    # Recursively search child nodes
    if node.respond_to?(:children)
      node.children.each do |child|
        next unless child.is_a?(Parser::AST::Node)
        matches.concat(find_actions_in_ast(child, controller_name))
      end
    end

    matches
  end

  def find_actions_in_hash(hash_node, controller_name)
    matches = []

    hash_node.children.each do |pair_node|
      next unless pair_node.type == :pair

      key_node = pair_node.children[0]
      value_node = pair_node.children[1]

      next unless key_node && value_node

      # Look for action keys
      if (key_node.type == :str && key_node.children[0] == "action") ||
         (key_node.type == :sym && key_node.children[0] == :action)

        if value_node.type == :str
          action_string = value_node.children[0]
          parsed_actions = parse_action_string(action_string)

          parsed_actions.each do |action|
            if controller_name.nil? || action[:controller] == controller_name
              matches << {
                type: :hash_action,
                action_string: action_string,
                parsed_action: action,
                key_node: key_node,
                value_node: value_node
              }
            end
          end
        end
      end
    end

    matches
  end

  def find_actions_in_method_call(send_node, controller_name)
    matches = []

    if send_node.children.length >= 2
      send_node.children[2..-1].each do |arg|
        next unless arg.is_a?(Parser::AST::Node) && arg.type == :hash
        matches.concat(find_actions_in_hash(arg, controller_name))
      end
    end

    matches
  end

  def find_values_in_ast(node, controller_name, value_name)
    return [] unless node

    matches = []

    case node.type
    when :hash
      matches.concat(find_values_in_hash(node, controller_name, value_name))
    when :send
      matches.concat(find_values_in_method_call(node, controller_name, value_name))
    end

    # Recursively search child nodes
    if node.respond_to?(:children)
      node.children.each do |child|
        next unless child.is_a?(Parser::AST::Node)
        matches.concat(find_values_in_ast(child, controller_name, value_name))
      end
    end

    matches
  end

  def find_values_in_hash(hash_node, controller_name, value_name)
    matches = []

    hash_node.children.each do |pair_node|
      next unless pair_node.type == :pair

      key_node = pair_node.children[0]
      value_node = pair_node.children[1]

      next unless key_node && value_node

      # Handle string keys: "controller-value-name-value" => "..."
      if key_node.type == :str
        key_str = key_node.children[0]
        kebab_value_name = value_name.gsub(/([a-z])([A-Z])/, '\1-\2').downcase
        expected_key = "#{controller_name}-#{kebab_value_name}-value"

        if key_str == expected_key
          matches << {
            type: :hash_string_key,
            controller: controller_name,
            value: value_name,
            key_node: key_node,
            value_node: value_node
          }
        end
      end

      # Handle symbol keys: controller_value_name_value: "..." or "controller-value-name-value": "..."
      if key_node.type == :sym
        key_sym = key_node.children[0]
        kebab_value_name = value_name.gsub(/([a-z])([A-Z])/, '\1-\2').downcase

        # Support both formats: underscore and hyphen
        expected_key_underscore = "#{controller_name.gsub('-', '_')}_#{value_name.gsub(/([a-z])([A-Z])/, '\1_\2').downcase}_value"
        expected_key_hyphen = "#{controller_name}-#{kebab_value_name}-value"

        if (key_sym.to_s == expected_key_underscore || key_sym.to_s == expected_key_hyphen)
          matches << {
            type: :hash_symbol_key,
            controller: controller_name,
            value: value_name,
            key_node: key_node,
            value_node: value_node
          }
        end
      end
    end

    matches
  end

  def find_values_in_method_call(send_node, controller_name, value_name)
    matches = []

    if send_node.children.length >= 2
      send_node.children[2..-1].each do |arg|
        next unless arg.is_a?(Parser::AST::Node) && arg.type == :hash
        matches.concat(find_values_in_hash(arg, controller_name, value_name))
      end
    end

    matches
  end

  def parse_action_string(action_string)
    return [] unless action_string

    actions = []
    action_parts = action_string.scan(/\S+/)

    action_parts.each do |action|
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


  def calculate_line_number(position)
    @content[0...position].count("\n") + 1
  end

  # Check if AST contains controller definition
  def contains_controller_in_ast?(node, controller_name)
    return false unless node

    case node.type
    when :hash
      node.children.each do |pair_node|
        next unless pair_node.type == :pair

        key_node = pair_node.children[0]
        value_node = pair_node.children[1]

        # Look for controller key with matching value
        if (key_node.type == :str && key_node.children[0] == "controller") ||
           (key_node.type == :sym && key_node.children[0] == :controller)

          if value_node.type == :str && value_node.children[0] == controller_name
            return true
          end
        end
      end
    when :send
      # Check method call arguments
      node.children[2..-1].each do |arg|
        next unless arg.is_a?(Parser::AST::Node)
        return true if contains_controller_in_ast?(arg, controller_name)
      end
    end

    # Recursively search child nodes
    if node.respond_to?(:children)
      node.children.each do |child|
        next unless child.is_a?(Parser::AST::Node)
        return true if contains_controller_in_ast?(child, controller_name)
      end
    end

    false
  end
end

RSpec.describe 'Simple Stimulus Validator', type: :system do
  let(:controllers_dir) { Rails.root.join('app/javascript/controllers') }
  let(:views_dir) { Rails.root.join('app/views') }

  let(:controller_data) do
    data = {}

    Dir.glob(controllers_dir.join('*_controller.ts')).each do |file|
      controller_name = File.basename(file, '.ts').gsub('_controller', '').gsub('_', '-')

      # Use TypeScript AST parser to extract controller metadata
      parser_script = Rails.root.join('bin/parse_ts_controller.js')
      result_json = `node #{parser_script} #{file}`

      if $?.success?
        parsed_data = JSON.parse(result_json)

        data[controller_name] = {
          targets: parsed_data['targets'] || [],
          optional_targets: parsed_data['optionalTargets'] || [],
          values: parsed_data['values'] || [],
          values_with_defaults: parsed_data['valuesWithDefaults'] || [],
          methods: parsed_data['methods'] || [],
          querySelectors: parsed_data['querySelectors'] || [],
          file: file
        }
      else
        raise 'Parse ts controller failed'
      end
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

  def find_exempt_methods(node, content, exempt_ranges)
    return unless node

    if node.type == :def
      method_name = node.children[0].to_s

      # Check if method name is webhook/callback or ends with _webhook/_callback
      if method_name.match?(/(^|_)(webhook|callback)$/)
        # Get line range for this method
        start_line = node.loc.line
        end_line = node.loc.last_line
        exempt_ranges << (start_line..end_line)
      end
    end

    # Recursively search child nodes
    node.children.each do |child|
      find_exempt_methods(child, content, exempt_ranges) if child.is_a?(Parser::AST::Node)
    end
  end

  def parse_erb_actions(content, relative_path)
    actions = []

    # Use AST parser to find actions in ERB blocks
    erb_parser = ErbAstParser.new(content)
    erb_actions = erb_parser.find_stimulus_actions

    erb_actions.each do |erb_action|
      action_info = erb_action[:match][:parsed_action]

      actions << {
        element: nil, # ERB actions don't have direct DOM elements
        action: action_info[:action],
        event: action_info[:event],
        controller: action_info[:controller],
        method: action_info[:method],
        source: 'erb_ast',
        line_number: erb_action[:line_number],
        line_content: action_info[:action]
      }
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

      # Check for data-controller attribute using simple string matching
      if line.include?('data-controller=') && line.include?(controller_name)
        # Verify it's actually the controller name (not a substring)
        if line.include?("\"#{controller_name}\"") || line.include?("'#{controller_name}'") ||
           line.include?("\"#{controller_name} ") || line.include?("'#{controller_name} ") ||
           line.include?(" #{controller_name}\"") || line.include?(" #{controller_name}'") ||
           line.include?(" #{controller_name} ")

          # Find the scope boundaries for this controller
          scope_start = line_num
          scope_end = find_scope_end(lines, index)
          controller_scopes << { start: scope_start, end: scope_end, line: line.strip }
        end
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
      target_scope_errors = []
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
              # Skip optional targets (those with hasXXXTarget declaration)
              next if controller_data[controller_name][:optional_targets].include?(target)

              target_found_in_scope = false

              # 1. Check if controller element itself has the target (HTML attribute)
              if controller_element["data-#{controller_name}-target"]&.include?(target)
                target_found_in_scope = true
              end

              # 2. If not found on controller element, look inside it (HTML descendants)
              unless target_found_in_scope
                target_selector = "[data-#{controller_name}-target*='#{target}']"
                target_found_in_scope = controller_element.css(target_selector).any?
              end

              # 3. Use AST parser to find targets in ERB blocks within controller scope
              unless target_found_in_scope
                erb_parser = ErbAstParser.new(content)
                erb_targets = erb_parser.find_stimulus_targets(controller_name, target)

                # Check if any ERB target is within the controller scope
                erb_targets.each do |erb_target|
                  # For now, consider ERB targets found if they exist anywhere in the file
                  # TODO: Implement proper scope checking for ERB blocks
                  target_found_in_scope = true
                  break
                end
              end

              unless target_found_in_scope
                # Check if target exists anywhere else in the file (out of scope)
                target_exists_elsewhere = false

                # Check HTML elements outside current controller scope
                doc.css("[data-#{controller_name}-target*='#{target}']").each do |element|
                  # Check if this element is outside the current controller scope
                  is_outside_scope = true
                  element.ancestors.each do |ancestor|
                    if ancestor == controller_element
                      is_outside_scope = false
                      break
                    end
                  end

                  if is_outside_scope
                    target_exists_elsewhere = true
                    break
                  end
                end

                # Check ERB blocks for targets outside scope
                unless target_exists_elsewhere
                  erb_parser = ErbAstParser.new(content)
                  erb_targets = erb_parser.find_stimulus_targets(controller_name, target)
                  # If ERB targets exist, they might be outside scope
                  # For simplicity, we consider them as potentially out of scope
                end

                if target_exists_elsewhere
                  # Target exists but is out of scope
                  target_scope_errors << {
                    controller: controller_name,
                    target: target,
                    file: relative_path,
                    error_type: "out_of_scope",
                    suggestion: "Move <div data-#{controller_name}-target=\"#{target}\">...</div> inside controller scope or move controller definition to parent element"
                  }
                else
                  # Target doesn't exist at all
                  target_errors << {
                    controller: controller_name,
                    target: target,
                    file: relative_path,
                    suggestion: "Add <div data-#{controller_name}-target=\"#{target}\">...</div> within controller scope or use ERB syntax: data: { \"#{controller_name}-target\" => \"#{target}\" }"
                  }
                end
              end
            end

            # Check for missing or incorrectly formatted values using AST parser
            controller_data[controller_name][:values].each do |value_name|
              # Skip values with default values
              next if controller_data[controller_name][:values_with_defaults].include?(value_name)

              kebab_value_name = value_name.gsub(/([a-z])([A-Z])/, '\1-\2').downcase
              expected_attr = "data-#{controller_name}-#{kebab_value_name}-value"
              value_found = false

              # 1. Check HTML attributes on controller element
              if controller_element.has_attribute?(expected_attr)
                value_found = true
              end

              # 2. Use AST parser to find values in ERB blocks
              unless value_found
                erb_parser = ErbAstParser.new(content)
                erb_values = erb_parser.find_stimulus_values(controller_name, value_name)

                if erb_values.any?
                  value_found = true
                end
              end

              # 3. Check for common mistakes using AST and string detection
              unless value_found
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
                    suggestion: "Change '#{found_mistakes.first}' to '#{expected_attr}'}"
                  }
                else
                  value_errors << {
                    controller: controller_name,
                    value: value_name,
                    file: relative_path,
                    expected: expected_attr,
                    found: nil,
                    suggestion: "Add #{expected_attr}=\"...\" to controller element}"
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
          if source == 'erb_ast'
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
            controller_scope = false

            # Check if element itself has the controller
            if action_element['data-controller']&.include?(controller_name)
              controller_scope = action_element
            else
              # Check ancestors for the controller (correct way)
              action_element.ancestors.each do |ancestor|
                if ancestor['data-controller']&.include?(controller_name)
                  controller_scope = ancestor
                  break
                end
              end
            end

            if !controller_scope && relative_path.include?('_')
              parent_controllers = get_controllers_from_parents(relative_path)
              if parent_controllers.include?(controller_name)
                controller_scope = true
              end
            end
          end

          unless controller_scope
            # Check if controller exists anywhere in the file using AST parsing
            controller_exists_in_file = false

            # Check HTML data-controller attributes
            doc.css('[data-controller]').each do |element|
              if element['data-controller'].split(/\s+/).include?(controller_name)
                controller_exists_in_file = true
                break
              end
            end

            # Check ERB blocks for controller definitions using AST
            unless controller_exists_in_file
              erb_parser = ErbAstParser.new(content)
              erb_parser.instance_variable_get(:@erb_blocks).each do |block|
                next unless block[:code].include?('data') && block[:code].include?('controller')

                begin
                  processed_code = erb_parser.send(:preprocess_erb_code, block[:code])
                  ast = Parser::CurrentRuby.parse(processed_code)
                  if contains_controller_in_ast?(ast, controller_name)
                    controller_exists_in_file = true
                    break
                  end
                rescue
                  # Skip unparseable blocks
                end
              end
            end

            if controller_exists_in_file
              # Controller exists but out of scope
              if relative_path.include?('_')
                suggestion = "Controller '#{controller_name}' exists but action is out of scope - move action within controller scope or define controller in parent template"
              else
                suggestion = "Controller '#{controller_name}' exists but action is out of scope - move action within <div data-controller=\"#{controller_name}\">...</div>"
              end
              error_type = "out_of_scope"
            else
              # Controller doesn't exist in file at all
              if relative_path.include?('_')
                suggestion = "Controller '#{controller_name}' should be defined in parent template or wrap with <div data-controller=\"#{controller_name}\">...</div>"
              else
                suggestion = "Wrap with <div data-controller=\"#{controller_name}\">...</div>"
              end
              error_type = "missing_controller"
            end

            scope_errors << {
              action: action,
              controller: controller_name,
              file: relative_path,
              is_partial: relative_path.include?('_'),
              parent_files: partial_parent_map[relative_path] || [],
              suggestion: suggestion,
              source: source,
              error_type: error_type
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

      total_errors = target_errors.length + target_scope_errors.length + action_errors.length + scope_errors.length + registration_errors.length + value_errors.length

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

        if target_scope_errors.any?
          puts "\n   🎯 Target Out of Scope Errors (#{target_scope_errors.length}):"
          target_scope_errors.each do |error|
            puts "     • #{error[:controller]}:#{error[:target]} exists but is out of controller scope in #{error[:file]}"
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
          out_of_scope_errors = scope_errors.select { |e| e[:error_type] == "out_of_scope" }
          missing_controller_errors = scope_errors.select { |e| e[:error_type] == "missing_controller" }

          if out_of_scope_errors.any?
            puts "\n   🚨 Out of Scope Errors (#{out_of_scope_errors.length}):"
            out_of_scope_errors.each do |error|
              if error[:is_partial] && error[:parent_files].any?
                puts "     • #{error[:action]} controller exists but action is out of scope in #{error[:file]} (partial rendered in: #{error[:parent_files].join(', ')})"
              else
                puts "     • #{error[:action]} controller exists but action is out of scope in #{error[:file]}"
              end
            end
          end

          if missing_controller_errors.any?
            puts "\n   🚨 Missing Controller Scope (#{missing_controller_errors.length}):"
            missing_controller_errors.each do |error|
              if error[:is_partial] && error[:parent_files].any?
                puts "     • #{error[:action]} needs controller scope in #{error[:file]} (partial rendered in: #{error[:parent_files].join(', ')})"
              else
                puts "     • #{error[:action]} needs controller scope in #{error[:file]}"
              end
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

        target_scope_errors.each do |error|
          error_details << "Target out of scope: #{error[:controller]}:#{error[:target]} in #{error[:file]} - #{error[:suggestion]}"
        end

        value_errors.each do |error|
          error_details << "Value error: #{error[:controller]}:#{error[:value]} in #{error[:file]} - #{error[:suggestion]}"
        end

        scope_errors.each do |error|
          if error[:error_type] == "out_of_scope"
            error_details << "Out of scope error: #{error[:action]} in #{error[:file]} - #{error[:suggestion]}"
          else
            error_details << "Scope error: #{error[:action]} in #{error[:file]} - #{error[:suggestion]}"
          end
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
        doc = Nokogiri::HTML::DocumentFragment.parse(content)

        controller_data.keys.each do |controller|
          # Check HTML data-controller attributes
          found_in_html = doc.css('[data-controller]').any? do |element|
            element['data-controller'].split(/\s+/).include?(controller)
          end

          # Check ERB blocks using AST
          found_in_erb = false
          unless found_in_html
            erb_parser = ErbAstParser.new(content)
            erb_parser.instance_variable_get(:@erb_blocks).each do |block|
              next unless block[:code].include?('data') && block[:code].include?('controller')

              begin
                processed_code = erb_parser.send(:preprocess_erb_code, block[:code])
                ast = Parser::CurrentRuby.parse(processed_code)
                if erb_parser.send(:contains_controller_in_ast?, ast, controller)
                  found_in_erb = true
                  break
                end
              rescue
                # Skip unparseable blocks
              end
            end
          end

          if found_in_html || found_in_erb
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
            # Parse action string using existing method
            parsed_actions = parse_action_string(action_attr)
            parsed_actions.each do |action_info|
              controller = action_info[:controller]
              unless controller_data.key?(controller)
                missing_controllers << controller
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

  describe 'Turbo Frame Prohibition Validation' do
    it 'ensures Turbo Frames are not used (Turbo Streams are allowed)' do
      turbo_violations = []

      # Turbo Frame patterns to check in views (FORBIDDEN)
      view_turbo_patterns = {
        'turbo_frame_tag' => 'Turbo Frame helper',
        'data-turbo-frame' => 'Turbo Frame data attribute',
        '<turbo-frame' => 'Turbo Frame HTML tag'
      }

      # Turbo Frame patterns to check in controllers (FORBIDDEN)
      controller_turbo_patterns = {
        'turbo_frame_request?' => 'Turbo Frame request check'
      }

      # Check view files
      view_files.each do |view_file|
        content = File.read(view_file)
        relative_path = view_file.sub(Rails.root.to_s + '/', '')

        view_turbo_patterns.each do |pattern, description|
          if content.include?(pattern)
            turbo_violations << {
              file: relative_path,
              pattern: pattern,
              description: description,
              suggestion: "Remove #{description} - use Turbo Streams instead (format.turbo_stream)"
            }
          end
        end
      end

      # Check controller files
      controller_files = Dir.glob(Rails.root.join('app/controllers/**/*_controller.rb'))
      controller_files.each do |controller_file|
        content = File.read(controller_file)
        relative_path = controller_file.sub(Rails.root.to_s + '/', '')

        controller_turbo_patterns.each do |pattern, description|
          if content.include?(pattern)
            turbo_violations << {
              file: relative_path,
              pattern: pattern,
              description: description,
              suggestion: "Remove #{description} - Turbo Frames not allowed (use format.turbo_stream instead)"
            }
          end
        end
      end

      if turbo_violations.any?
        puts "\n🚫 Turbo Frame Usage Detected (#{turbo_violations.length}):"
        turbo_violations.each do |violation|
          puts "   • #{violation[:file]}: Found '#{violation[:pattern]}' (#{violation[:description]})"
        end

        error_details = turbo_violations.map do |v|
          "#{v[:file]}: #{v[:pattern]} - #{v[:suggestion]}"
        end

        expect(turbo_violations).to be_empty, "Turbo Frames are not allowed (Turbo Streams are OK):\n#{error_details.join("\n")}"
      else
        puts "\n✅ No Turbo Frame usage detected - Turbo Streams enabled!"
      end
    end
  end

  describe 'QuerySelector Validation' do
    it 'validates that querySelector calls target elements within controller scope' do
      selector_errors = []
      selector_scope_errors = []

      controller_data.each do |controller_name, data|
        query_selectors = data[:querySelectors] || []
        next if query_selectors.empty?

        # Find view files that use this controller
        view_files.each do |view_file|
          content = File.read(view_file)
          relative_path = view_file.sub(Rails.root.to_s + '/', '')
          doc = Nokogiri::HTML::DocumentFragment.parse(content)

          # Find all elements with this controller
          controller_elements = doc.css("[data-controller]").select do |element|
            element['data-controller'].split(/\s+/).include?(controller_name)
          end

          next if controller_elements.empty?

          # Check each querySelector call
          query_selectors.each do |qs|
            selector = qs['selector']
            method = qs['method']
            in_method = qs['inMethod']
            line = qs['line']
            is_template = qs['isTemplate']

            # Skip template literals for now (they're dynamic)
            if is_template
              next
            end

            # Track if we found the selector in at least one controller scope
            found_in_scope = false
            found_outside_scope = false

            controller_elements.each do |controller_element|
              # Try to find elements matching the selector within the controller scope
              begin
                matching_elements = controller_element.css(selector)
                if matching_elements.any?
                  found_in_scope = true
                  break
                end
              rescue Nokogiri::CSS::SyntaxError
                # Invalid CSS selector, skip
                next
              end
            end

            # Check if selector exists elsewhere in the document (outside controller scope)
            unless found_in_scope
              begin
                matching_elements = doc.css(selector)
                if matching_elements.any?
                  # Check if these elements are outside all controller scopes
                  matching_elements.each do |element|
                    is_outside = controller_elements.all? do |controller_element|
                      !controller_element.css('*').include?(element) && element != controller_element
                    end
                    if is_outside
                      found_outside_scope = true
                      break
                    end
                  end
                end
              rescue Nokogiri::CSS::SyntaxError
                # Invalid CSS selector, skip
                next
              end
            end

            unless found_in_scope
              controller_file = data[:file].sub(Rails.root.to_s + '/', '')

              if found_outside_scope
                # Selector exists but is out of scope
                selector_scope_errors << {
                  controller: controller_name,
                  selector: selector,
                  method: in_method,
                  line: line,
                  controller_file: controller_file,
                  view_file: relative_path,
                  suggestion: "Selector '#{selector}' exists in #{relative_path} but is outside the '#{controller_name}' controller scope. Move the element(s) inside <div data-controller=\"#{controller_name}\">...</div> or adjust the selector."
                }
              else
                # Selector doesn't exist at all
                selector_errors << {
                  controller: controller_name,
                  selector: selector,
                  method: in_method,
                  line: line,
                  controller_file: controller_file,
                  view_file: relative_path,
                  suggestion: "Selector '#{selector}' not found in #{relative_path}. Add an element with this selector within the '#{controller_name}' controller scope, or the querySelector call in #{in_method}() may fail at runtime."
                }
              end
            end
          end
        end
      end

      total_errors = selector_errors.length + selector_scope_errors.length

      puts "\n🔍 QuerySelector Validation Results:"
      total_selectors = controller_data.values.map { |d| (d[:querySelectors] || []).length }.sum
      puts "   📁 Found: #{total_selectors} querySelector calls across #{controller_data.keys.length} controllers"

      if total_errors == 0
        puts "   ✅ All querySelector calls are valid!"
      else
        puts "\n   ❌ Found #{total_errors} issue(s):"

        if selector_errors.any?
          puts "\n   🔍 Missing Selectors (#{selector_errors.length}):"
          selector_errors.each do |error|
            puts "     • #{error[:controller]}##{error[:method]}() at #{error[:controller_file]}:#{error[:line]}"
            puts "       Selector '#{error[:selector]}' not found in #{error[:view_file]}"
          end
        end

        if selector_scope_errors.any?
          puts "\n   🔍 Selector Out of Scope Errors (#{selector_scope_errors.length}):"
          selector_scope_errors.each do |error|
            puts "     • #{error[:controller]}##{error[:method]}() at #{error[:controller_file]}:#{error[:line]}"
            puts "       Selector '#{error[:selector]}' exists but is out of scope in #{error[:view_file]}"
          end
        end

        error_details = []

        selector_errors.each do |error|
          error_details << "Missing selector: #{error[:controller]}##{error[:method]}() uses '#{error[:selector]}' at #{error[:controller_file]}:#{error[:line]} - #{error[:suggestion]}"
        end

        selector_scope_errors.each do |error|
          error_details << "Selector out of scope: #{error[:controller]}##{error[:method]}() uses '#{error[:selector]}' at #{error[:controller_file]}:#{error[:line]} - #{error[:suggestion]}"
        end

        expect(total_errors).to eq(0), "QuerySelector validation failed:\n#{error_details.join("\n")}"
      end
    end
  end

  describe 'Turbo Stream Architecture Enforcement' do
    it 'validates frontend-backend interactions use Turbo Streams exclusively' do
      violations = []

      # Check backend controllers
      controller_files = Dir.glob(Rails.root.join('app/controllers/**/*_controller.rb'))

      controller_files.each do |file|
        content = File.read(file)
        relative_path = file.sub(Rails.root.to_s + '/', '')

        # Skip API namespace (explicit API endpoints can use JSON)
        next if relative_path.include?('app/controllers/api/')

        # Parse controller file with AST to find webhook/callback methods
        exempt_method_ranges = []
        begin
          ast = Parser::CurrentRuby.parse(content)
          find_exempt_methods(ast, content, exempt_method_ranges)
        rescue Parser::SyntaxError
          # If parsing fails, skip AST-based exemption (fall back to line-by-line)
        end

        lines = content.split("\n")

        lines.each_with_index do |line, index|
          line_number = index + 1
          stripped = line.strip

          # Skip JSON checks if current line is inside a webhook/callback method
          next if exempt_method_ranges.any? { |range| range.cover?(line_number) }

          # Detect head :ok / head :no_content
          if stripped.match?(/\bhead\s+:(ok|no_content)\b/)
            violations << {
              file: relative_path,
              line: line_number,
              code: stripped,
              type: 'head :ok',
              issue: 'Lacks explicit frontend interaction feedback',
              suggestion: 'Use Turbo Stream to provide specific UI update instructions'
            }
          end

          # Detect render json:
          if stripped.match?(/\brender\s+json:/)
            violations << {
              file: relative_path,
              line: line_number,
              code: stripped,
              type: 'render json:',
              issue: 'JSON response requires manual frontend data handling and DOM updates',
              suggestion: 'Use Turbo Stream for server-rendered HTML fragments'
            }
          end

          # Detect format.json
          if stripped.match?(/format\.json\b/)
            violations << {
              file: relative_path,
              line: line_number,
              code: stripped,
              type: 'format.json',
              issue: 'JSON format increases frontend-backend data synchronization complexity',
              suggestion: 'Use format.turbo_stream for server-side rendering'
            }
          end
        end
      end

      # Check frontend Stimulus controllers for fetch usage (forbidden)
      ts_controller_files = Dir.glob(controllers_dir.join('*_controller.ts'))

      ts_controller_files.each do |file|
        content = File.read(file)
        relative_path = file.sub(Rails.root.to_s + '/', '')
        lines = content.split("\n")

        lines.each_with_index do |line, index|
          line_number = index + 1

          # Detect fetch() calls (forbidden)
          if line.match?(/\bfetch\s*\(/)
            violations << {
              file: relative_path,
              line: line_number,
              code: line.strip,
              type: 'fetch()',
              issue: 'Using fetch() breaks Turbo Stream architecture and requires manual response handling',
              suggestion: 'Use form submission (form.requestSubmit()) to let Turbo handle the interaction'
            }
          end
        end
      end

      if violations.any?
        puts "\n⚠️  Frontend-Backend Architecture Notice (#{violations.length} area(s) for improvement):"
        puts "   📋 Architecture Principle: This project uses pure Turbo Stream architecture"
        puts "   🎯 Goal: Reduce frontend complexity and avoid manual DOM manipulation errors\n"

        violations.group_by { |v| v[:file] }.each do |file, file_violations|
          puts "   📄 #{file}:"
          file_violations.each do |v|
            puts "      Line #{v[:line]}: #{v[:code]}"
            puts "      ⚠️  Issue: #{v[:issue]}"
            puts "      ✅ Suggestion: #{v[:suggestion]}\n"
          end
        end

        puts "   ℹ️  Why this matters:"
        puts "      • head :ok only returns status code, frontend cannot determine what to update"
        puts "      • JSON responses require manual DOM updates, easy to miss related elements (e.g. counters)"
        puts "      • Turbo Stream lets backend control UI updates, ensuring interaction completeness"
        puts "      • API endpoints (app/controllers/api/) are exempt from this requirement\n"

        error_details = violations.map do |v|
          "#{v[:file]}:#{v[:line]} - #{v[:type]}: #{v[:issue]}"
        end

        expect(violations).to be_empty,
          "Frontend-backend interactions must use Turbo Stream architecture:\n#{error_details.join("\n")}"
      else
        puts "\n✅ Frontend-backend architecture validated: All interactions use Turbo Streams!"
      end
    end
  end
end
