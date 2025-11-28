require 'herb'
require_relative 'config'

module SourceMapping
  # Visitor class to traverse the AST
  class SourceMappingVisitor < Herb::Visitor
    def initialize(source, filename, modifications)
      @source = source
      @filename = filename
      @modifications = modifications
      super()
    end

    def visit_html_element_node(node)
      process_html_element(node)
      super(node)  # Continue visiting children
    end

    private

    def process_html_element(node)
      # Get tag name
      tag_name = extract_tag_name(node)
      is_void_element = SourceMapping::HerbErbPreprocessor::VOID_ELEMENTS.include?(tag_name&.downcase)

      # Check if already has source location attribute
      return if has_source_location_attribute?(node)

      # Build attributes to inject
      attrs = []

      # Add source location
      if node.location
        start_line = node.location.start.line
        start_col = node.location.start.column + 1  # Convert to 1-based
        end_line = node.location.end.line
        end_col = node.location.end.column + 1  # Convert to 1-based
        attrs << "data-clacky-source-loc=\"#{@filename}:#{start_line}:#{start_col}:#{end_line}:#{end_col}\""
      end

      # Add class location (for all elements including void elements)
      # class_info = extract_class_location(node)
      # attrs << "data-clacky-class=\"#{class_info}\"" if class_info

      # Add style location (for all elements including void elements)
      style_info = extract_style_location(node)
      attrs << "data-clacky-style=\"#{style_info}\"" if style_info

      # Add text location (only for non-void elements)
      if !is_void_element
        text_info = extract_text_location(node)
        attrs << "data-clacky-text=\"#{text_info}\"" if text_info
      end

      # Find insertion position (after tag name)
      if attrs.any?
        insertion_pos = find_insertion_position(node)
        if insertion_pos
          @modifications << {
            position: insertion_pos,
            attributes: " #{attrs.join(' ')}"
          }
        end
      end
    end

    def extract_tag_name(node)
      return nil unless node.respond_to?(:tag_name)

      # According to the documentation, tag_name should be accessible
      tag_name = node.tag_name
      if tag_name.respond_to?(:content)
        tag_name.content
      elsif tag_name.is_a?(String)
        tag_name
      elsif tag_name.respond_to?(:location)
        # Extract from source using location
        extract_from_location(tag_name.location)
      else
        nil
      end
    end

    def has_source_location_attribute?(node)
      return false unless node.respond_to?(:open_tag) && node.open_tag

      # Check if open_tag has attributes
      if node.open_tag.respond_to?(:children)
        node.open_tag.children.any? do |child|
          if child.class.to_s.include?('HTMLAttribute')
            attr_name = extract_attribute_name(child)
            attr_name == 'data-clacky-source-loc'
          end
        end
      else
        false
      end
    end

    def extract_attribute_name(attr_node)
      # Try different ways to get attribute name
      if attr_node.respond_to?(:name)
        name = attr_node.name
        if name.respond_to?(:content)
          name.content
        elsif name.respond_to?(:location)
          extract_from_location(name.location)
        end
      end
    end

    def extract_class_location(node)
      return nil unless node.respond_to?(:open_tag) && node.open_tag

      # Find class attribute
      class_attr = nil
      if node.open_tag.respond_to?(:children)
        class_attr = node.open_tag.children.find do |child|
          if child.class.to_s.include?('HTMLAttribute')
            extract_attribute_name(child) == 'class'
          end
        end
      end

      if class_attr
        # Get the value location
        value_node = class_attr.value if class_attr.respond_to?(:value)

        if value_node && value_node.respond_to?(:location)
          # Check for ERB interpolation in value
          if has_erb_interpolation?(value_node)
            return nil
          end

          # Get the location and adjust for quotes
          # herb uses 1-based lines and 0-based columns
          loc = value_node.location
          start_line = loc.start.line
          start_col = loc.start.column + 1 + 1  # Skip opening quote and convert to 1-based
          end_line = loc.end.line
          end_col = loc.end.column  # Right-open: point after last character (excluding closing quote)

          "#{start_line}:#{start_col}:#{end_line}:#{end_col}"
        end
      else
        # No class attribute, return position after tag name
        if node.respond_to?(:tag_name) && node.tag_name.respond_to?(:location)
          loc = node.tag_name.location
          line = loc.end.line
          col = loc.end.column + 1  # convert to 1-based
          "#{line}:#{col}:#{line}:#{col}"
        end
      end
    end

    def extract_style_location(node)
      return nil unless node.respond_to?(:open_tag) && node.open_tag

      # Find style attribute
      style_attr = nil
      if node.open_tag.respond_to?(:children)
        style_attr = node.open_tag.children.find do |child|
          if child.class.to_s.include?('HTMLAttribute')
            extract_attribute_name(child) == 'style'
          end
        end
      end

      if style_attr
        # Get the value location
        value_node = style_attr.value if style_attr.respond_to?(:value)

        if value_node && value_node.respond_to?(:location)
          # Check for ERB interpolation in value
          if has_erb_interpolation?(value_node)
            return nil
          end

          # Get the location and adjust for quotes
          # herb uses 1-based lines and 0-based columns
          loc = value_node.location
          start_line = loc.start.line
          start_col = loc.start.column + 1 + 1  # Skip opening quote and convert to 1-based
          end_line = loc.end.line
          end_col = loc.end.column  # Right-open: point after last character (excluding closing quote)

          "#{start_line}:#{start_col}:#{end_line}:#{end_col}"
        end
      else
        # No style attribute, return position after tag name
        if node.respond_to?(:tag_name) && node.tag_name.respond_to?(:location)
          loc = node.tag_name.location
          line = loc.end.line
          col = loc.end.column + 1  # convert to 1-based
          "#{line}:#{col}:#{line}:#{col}"
        end
      end
    end

    def extract_text_location(node)
      # Check if element contains any ERB nodes
      if has_erb_content?(node)
        return nil
      end

      # Find text nodes within this element
      text_nodes = find_text_nodes(node)

      # Collect non-empty text nodes
      non_empty_text_nodes = []
      text_nodes.each do |text_node|
        next unless text_node.respond_to?(:content) && text_node.respond_to?(:location)

        content = text_node.content
        # Skip if empty or whitespace only
        next if content.strip.empty?

        non_empty_text_nodes << text_node
      end

      # If there are multiple non-empty text nodes, consider it non-editable
      # This handles cases like: <button>View <br> Collection</button>
      # or <p>Hello <strong>world</strong>!</p>
      return nil if non_empty_text_nodes.length != 1

      # Process the single text node
      text_node = non_empty_text_nodes.first
      content = text_node.content

      # Calculate trimmed boundaries
      trimmed = content.lstrip
      trim_start = content.length - trimmed.length
      trimmed = trimmed.rstrip

      return nil if trimmed.empty?

      # Convert to position offsets
      loc = text_node.location
      start_offset = location_to_offset(loc.start) + trim_start
      end_offset = start_offset + trimmed.length  # Right-open: point after last character

      # Convert back to line:col (1-based, columns in UTF-16 code units for JS compatibility)
      start_line = @source[0...start_offset].count("\n") + 1
      # Find previous newline, avoiding the case where offset itself is a newline
      prev_newline_start = @source.rindex("\n", start_offset - 1)
      line_start = (prev_newline_start || -1) + 1
      text_before_start = @source[line_start...start_offset]
      start_col = utf16_length(text_before_start) + 1  # 1-based

      end_line = @source[0...end_offset].count("\n") + 1
      # Find previous newline, avoiding the case where offset itself is a newline
      prev_newline_end = @source.rindex("\n", end_offset - 1)
      line_start_end = (prev_newline_end || -1) + 1
      text_before_end = @source[line_start_end...end_offset]
      end_col = utf16_length(text_before_end) + 1  # 1-based

      "#{start_line}:#{start_col}:#{end_line}:#{end_col}"
    end

    def find_text_nodes(node)
      text_nodes = []

      # Check body if available
      if node.respond_to?(:body) && node.body.is_a?(Array)
        node.body.each do |child|
          if child.class.to_s.include?('HTMLText')
            text_nodes << child
          end
        end
      end

      # Check children if available
      if node.respond_to?(:children) && node.children
        node.children.each do |child|
          if child.class.to_s.include?('HTMLText')
            text_nodes << child
          end
        end
      end

      text_nodes
    end

    def has_erb_interpolation?(node)
      # Check if node contains ERB content
      return true if node.class.to_s.include?('ERB')

      if node.respond_to?(:children)
        node.children.any? { |child| child.class.to_s.include?('ERB') }
      else
        false
      end
    end

    def has_erb_content?(node)
      # Check if element body contains any ERB nodes
      if node.respond_to?(:body) && node.body.is_a?(Array)
        return node.body.any? { |child| child.class.to_s.include?('ERB') }
      end

      # Check children if available
      if node.respond_to?(:children) && node.children
        return node.children.any? { |child| child.class.to_s.include?('ERB') }
      end

      false
    end

    def find_insertion_position(node)
      # Find position right after tag name
      if node.respond_to?(:tag_name) && node.tag_name.respond_to?(:location)
        loc = node.tag_name.location
        location_to_offset(loc.end)
      elsif node.respond_to?(:open_tag) && node.open_tag.respond_to?(:location)
        # Fallback: find tag name in open_tag
        loc = node.open_tag.location
        start_offset = location_to_offset(loc.start)

        # Find end of tag name (look for first space or >)
        tag_content = @source[start_offset..-1]
        if match = tag_content.match(/^<(\w+)/)
          start_offset + match[0].length
        else
          start_offset + 1
        end
      else
        nil
      end
    end

    def extract_from_location(location)
      return nil unless location

      start_offset = location_to_offset(location.start)
      end_offset = location_to_offset(location.end)
      @source[start_offset...end_offset]
    end

    def location_to_offset(position)
      return 0 unless position

      line = position.line
      column = position.column

      lines = @source.lines
      offset = 0

      # Add all complete lines before the target line
      # herb uses 1-based lines, so we need (line - 1)
      (line - 1).times do |i|
        offset += lines[i].length if lines[i]
      end

      # Add the column offset
      # herb uses 0-based columns, so we add directly
      offset + column
    end

    # Convert offset to 1-based line and column numbers
    def offset_to_line_col(offset)
      lines_before = @source[0...offset].count("\n")
      line = lines_before + 1  # Convert to 1-based

      # Find column by looking for the last newline before the offset
      last_newline = @source.rindex("\n", offset - 1) || -1
      col = offset - last_newline  # This gives us 1-based column

      [line, col]
    end

    # Convert herb's position (1-based line, 0-based column) to user-friendly 1-based line and column
    def position_to_user_friendly(position)
      return [1, 1] unless position
      [position.line, position.column + 1]  # Convert column to 1-based
    end

    # Calculate UTF-16 code unit length (for JavaScript compatibility)
    # Emoji and other characters above U+FFFF use surrogate pairs (2 code units)
    def utf16_length(str)
      return 0 if str.nil? || str.empty?
      str.each_codepoint.sum { |cp| cp > 0xFFFF ? 2 : 1 }
    end
  end

  class HerbErbPreprocessor
    attr_reader :source, :filename

    VOID_ELEMENTS = %w[area base br col embed hr img input link meta param source track wbr]

    def initialize(source, filename)
      @source = source
      @filename = filename.sub(Rails.root.to_s + '/', '')
      @modifications = []
    end

    def process
      begin
        # Parse ERB template using Herb
        result = Herb.parse(@source)

        # Use visitor pattern to traverse AST
        visitor = SourceMappingVisitor.new(@source, @filename, @modifications)
        result.visit(visitor)

        # Apply modifications in reverse order to maintain positions
        apply_modifications
      rescue => e
        Rails.logger.error "HerbErbPreprocessor error: #{e.message}\n#{e.backtrace.join("\n")}"
        @source
      end
    end

    private

    def apply_modifications
      # Sort modifications by position (reverse order to maintain indices)
      @modifications.sort_by! { |m| -m[:position] }

      result = @source.dup
      @modifications.each do |mod|
        result.insert(mod[:position], mod[:attributes])
      end

      result
    end
  end
end
