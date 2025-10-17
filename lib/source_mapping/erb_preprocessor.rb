require_relative 'config'

module SourceMapping
  class ErbPreprocessor
    attr_reader :source, :filename, :line_mapping

    def initialize(source, filename)
      @source = source
      @filename = filename.sub(Rails.root.to_s + '/', '')
      @line_mapping = {}
      @source_id_attr = Config.source_id_attribute
    end

    def process
      return source unless Rails.env.development?

      lines = source.lines
      processed_lines = []
      in_erb_tag = false
      in_html_comment = false
      multiline_tag_buffer = ""
      multiline_start_line = 0

      lines.each_with_index do |line, index|
        line_number = index + 1

        # If processing a multiline tag
        if !multiline_tag_buffer.empty?
          # Find tag end position
          tag_end = find_tag_end(line, 0)

          if tag_end
            # Found tag end, combine complete tag
            multiline_tag_buffer << "\n" << line[0..tag_end]
            processed_tag = inject_source_id(multiline_tag_buffer, "#{filename}:#{multiline_start_line}")
            processed_line = processed_tag + line[(tag_end + 1)..-1]
            multiline_tag_buffer = ""
            multiline_start_line = 0
            processed_lines << processed_line
          else
            # Tag not ended yet, continue buffering
            multiline_tag_buffer << "\n" << line.chomp
            # Skip this line, output nothing
          end
          next
        end

        processed_line = ""
        i = 0

        while i < line.length
          # Check ERB tag start
          if line[i, 2] == '<%'
            in_erb_tag = true
            processed_line << line[i, 2]
            i += 2
            next
          end

          # Check ERB tag end
          if line[i, 2] == '%>' && in_erb_tag
            in_erb_tag = false
            processed_line << line[i, 2]
            i += 2
            next
          end

          # Check HTML comment start
          if line[i, 4] == '<!--'
            in_html_comment = true
            processed_line << line[i, 4]
            i += 4
            next
          end

          # Check HTML comment end
          if line[i, 3] == '-->' && in_html_comment
            in_html_comment = false
            processed_line << line[i, 3]
            i += 3
            next
          end

          # If in ERB tag or HTML comment, copy character directly
          if in_erb_tag || in_html_comment
            processed_line << line[i]
            i += 1
            next
          end

          # Check HTML tag
          if line[i] == '<' && line[i + 1] =~ /[a-zA-Z]/
            # Find tag end position
            tag_end = find_tag_end(line, i)

            if tag_end
              # Complete tag on current line
              tag = line[i..tag_end]
              processed_tag = inject_source_id(tag, "#{filename}:#{line_number}")
              processed_line << processed_tag
              i = tag_end + 1
            else
              # Tag spans multiple lines
              multiline_tag_buffer = line[i..-1].chomp
              multiline_start_line = line_number
              break
            end
          else
            processed_line << line[i]
            i += 1
          end
        end

        processed_lines << processed_line unless multiline_tag_buffer.length > 0
      end

      processed_lines.join
    end

    private

    def find_tag_end(line, start_pos)
      in_quotes = false
      quote_char = nil
      i = start_pos

      while i < line.length
        char = line[i]

        # Handle quotes
        if (char == '"' || char == "'") && line[i - 1] != '\\'
          if in_quotes && char == quote_char
            in_quotes = false
            quote_char = nil
          elsif !in_quotes
            in_quotes = true
            quote_char = char
          end
        end

        # Found tag end
        if char == '>' && !in_quotes
          return i
        end

        i += 1
      end

      nil
    end

    def inject_source_id(tag, source_id)
      # Skip tags that already have source attribute
      return tag if tag.include?(@source_id_attr)

      # Skip self-closing void elements (e.g., <br>, <img>, <input>)
      void_elements = %w[area base br col embed hr img input link meta param source track wbr]
      tag_name = tag.match(/<([a-zA-Z]+)/)[1].downcase rescue nil
      return tag if void_elements.include?(tag_name) && !tag.include?(@source_id_attr)

      # Find first space or > position to insert attribute
      # Use more precise tag processing
      if match = tag.match(/^(<[a-zA-Z][\w-]*)(.*)$/m)
        tag_start = match[1]
        tag_rest = match[2]

        # Build attribute string
        attributes = " #{@source_id_attr}=\"#{source_id}\""

        # Insert attributes directly after tag name
        "#{tag_start}#{attributes}#{tag_rest}"
      else
        tag
      end
    end
  end
end