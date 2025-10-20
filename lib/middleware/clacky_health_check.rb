# Middleware to handle health check requests from Clacky monitoring service
# Returns 200 OK immediately without logging or processing through Rails stack
class ClackyHealthCheck
  def initialize(app)
    @app = app
  end

  def call(env)
    # Check if User-Agent contains "clacky" (case-insensitive)
    user_agent = env['HTTP_USER_AGENT'].to_s

    if user_agent.match?(/clacky/i)
      # Return 200 OK immediately without further processing
      # No logging, no Rails stack, no database queries
      return [200, {'Content-Type' => 'text/plain'}, ['OK']]
    end

    # Pass through to the next middleware for all other requests
    @app.call(env)
  end
end
