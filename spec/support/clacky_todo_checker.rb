# Shared helper for checking CLACKY_TODO comments in generated code
# This ensures developers implement required functionality before deploying
module ClackyTodoChecker
  # Check if any CLACKY_TODO comments exist in the specified files
  # @param files [Array<String>] Array of file paths relative to Rails.root
  # @return [void] Fails the test if TODOs are found
  def check_clacky_todos(files)
    todos_found = []

    files.each do |file_path|
      full_path = Rails.root.join(file_path)
      next unless File.exist?(full_path)

      content = File.read(full_path)

      # Extract CLACKY_TODO and its description
      content.scan(/CLACKY_TODO:\s*(.+)/) do |match|
        todos_found << {
          file: file_path,
          description: match[0].strip
        }
      end
    end

    return if todos_found.empty?

    error_message = "\n❌ Found #{todos_found.length} unresolved CLACKY_TODO(s):\n\n"

    todos_found.each do |todo|
      error_message += "📄 #{todo[:file]}\n"
      error_message += "   TODO: #{todo[:description]}\n\n"
    end

    error_message += "Please implement the required functionality and remove CLACKY_TODO comments.\n"

    fail error_message
  end
end

RSpec.configure do |config|
  config.include ClackyTodoChecker
end
