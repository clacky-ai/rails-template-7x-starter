# Development-only tmp file server middleware
# Using 00_ prefix to ensure early loading

if Rails.env.development?
  # Define middleware inline to avoid autoload issues
  class TmpFileServer
    def initialize(app)
      @app = app
    end

    def call(env)
      request = Rack::Request.new(env)
      
      if request.path_info.start_with?('/tmp/')
        serve_tmp_file(request)
      else
        @app.call(env)
      end
    end

    private

    def serve_tmp_file(request)
      relative_path = request.path_info.sub(/^\/tmp\//, '')
      file_path = Rails.root.join('tmp', relative_path)

      # Security check
      return [403, { 'Content-Type' => 'text/plain' }, ['Forbidden']] unless file_path.to_s.start_with?(Rails.root.join('tmp').to_s)
      return [404, { 'Content-Type' => 'text/plain' }, ['Not Found']] unless File.exist?(file_path) && File.file?(file_path)

      content_type = case File.extname(file_path).downcase
                    when '.html', '.htm' then 'text/html'
                    when '.js' then 'application/javascript'
                    when '.css' then 'text/css'
                    when '.json' then 'application/json'
                    else 'text/plain'
                    end

      content = File.read(file_path)
      [200, { 'Content-Type' => "#{content_type}; charset=utf-8", 'Cache-Control' => 'no-cache' }, [content]]
    rescue => e
      Rails.logger.error "TmpFileServer error: #{e.message}"
      [500, { 'Content-Type' => 'text/plain' }, ['Server Error']]
    end
  end
  
  # Insert middleware at the beginning of the stack
  Rails.application.config.middleware.insert_before 0, TmpFileServer
end
