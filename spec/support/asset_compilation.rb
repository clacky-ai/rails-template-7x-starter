RSpec.configure do |config|
  config.before(:suite) do
    # Only check asset compilation when system tests are present
    if RSpec.world.example_groups.any? { |group| group.metadata[:type] == :system }
      ensure_assets_compiled
    end
  end

  private

  def ensure_assets_compiled
    return unless needs_compilation?

    puts "📦 Compiling assets for system tests..."

    # Capture both stdout and stderr
    output = `npm run build 2>&1`
    result = $?.success?

    unless result
      puts "\n" + "=" * 80
      puts "❌ Asset compilation failed - Tests aborted"
      puts "=" * 80

      # Extract and display key error information
      error_lines = output.split("\n").select do |line|
        line.include?('error') || line.include?('Error') ||
        line.include?('failed') || line.include?('Failed') ||
        line.include?('✘') || line.include?('×')
      end

      if error_lines.any?
        puts "\n🔍 Key errors:"
        error_lines.first(10).each { |line| puts "   #{line}" }
        puts "\n💡 Run 'npm run build' to see full output" if error_lines.length > 10
      else
        # Show last 20 lines if no specific errors found
        puts "\n📋 Last output lines:"
        output.split("\n").last(20).each { |line| puts "   #{line}" }
      end

      puts "=" * 80 + "\n"
      abort("Asset compilation failed. Fix the errors above and re-run tests.")
    end

    puts "✅ Assets compiled successfully"
  end

  def needs_compilation?
    js_files = Dir.glob("app/javascript/**/*.{js,ts,tsx}")
    css_files = Dir.glob("app/assets/stylesheets/**/*.css")

    # Check if build output directory exists
    return true unless Dir.exist?("app/assets/builds")

    # Filter out directories, only keep files
    built_files = Dir.glob("app/assets/builds/**/*").select { |f| File.file?(f) }
    return true if built_files.empty?

    # Compare modification times between source and built files
    source_files = js_files + css_files
    return true if source_files.empty?

    latest_source = source_files.map { |f| File.mtime(f) }.max
    latest_built = built_files.map { |f| File.mtime(f) }.max

    latest_source > latest_built
  end
end
