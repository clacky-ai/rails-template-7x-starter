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

    result = system("RAILS_ENV=test bin/rails assets:precompile",
                   out: File::NULL, err: File::NULL)

    unless result
      puts "❌ Asset compilation failed"
      exit(1)
    end

    puts "✅ Assets compiled successfully"
  end

  def needs_compilation?
    js_files = Dir.glob("app/javascript/**/*.{js,ts,tsx}")
    css_files = Dir.glob("app/assets/stylesheets/**/*.css")

    # Check if build output directory exists
    return true unless Dir.exist?("app/assets/builds")

    built_files = Dir.glob("app/assets/builds/**/*")
    return true if built_files.empty?

    # Compare modification times between source and built files
    source_files = js_files + css_files
    return true if source_files.empty?

    latest_source = source_files.map { |f| File.mtime(f) }.max
    latest_built = built_files.map { |f| File.mtime(f) }.max

    latest_source > latest_built
  end
end