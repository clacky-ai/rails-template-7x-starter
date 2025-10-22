# LLM Service - Unified LLM API wrapper
# Default streaming API with blocking fallback
# call(&block) - streaming by default, blocking if no block given
class LlmService < ApplicationService
  class LlmError < StandardError; end
  class TimeoutError < LlmError; end
  class ApiError < LlmError; end

  def initialize(prompt:, system: nil, **options)
    @prompt = prompt
    @system = system
    @options = options
    @model = options[:model] || ENV.fetch('LLM_MODEL')
    @temperature = options[:temperature]&.to_f || 0.7
    @max_tokens = options[:max_tokens] || 4000
    @timeout = options[:timeout] || 30
    @images = normalize_images(options[:images])
  end

  # Default call - streaming if block given, blocking otherwise
  def call(&block)
    if block_given?
      call_stream(&block)
    else
      call_blocking
    end
  end

  # Explicit blocking call (returns full response)
  def call_blocking
    raise LlmError, "Prompt cannot be blank" if @prompt.blank?

    response = make_http_request(stream: false)
    content = response.dig("choices", 0, "message", "content")

    raise LlmError, "No content in response" if content.blank?

    content
  rescue => e
    Rails.logger.error("LLM Error: #{e.class} - #{e.message}")
    raise
  end

  # Explicit streaming call (yields chunks as they arrive)
  def call_stream(&block)
    raise LlmError, "Prompt cannot be blank" if @prompt.blank?
    raise LlmError, "Block required for streaming" unless block_given?

    full_content = ""

    make_http_request(stream: true) do |chunk|
      full_content += chunk
      block.call(chunk)
    end

    full_content
  rescue => e
    Rails.logger.error("LLM Stream Error: #{e.class} - #{e.message}")
    raise
  end

  # Class method shortcuts
  class << self
    # Default: streaming if block, blocking otherwise
    def call(prompt:, system: nil, **options, &block)
      new(prompt: prompt, system: system, **options).call(&block)
    end

    # Explicit blocking call
    def call_blocking(prompt:, system: nil, **options)
      new(prompt: prompt, system: system, **options).call_blocking
    end

    # Explicit streaming call
    def call_stream(prompt:, system: nil, **options, &block)
      new(prompt: prompt, system: system, **options).call_stream(&block)
    end
  end

  private

  def make_http_request(stream: false, &block)
    require 'net/http'
    require 'uri'
    require 'json'

    http, request = prepare_http_request(stream)

    if stream
      handle_stream_response(http, request, &block)
    else
      handle_blocking_response(http, request)
    end
  rescue Net::ReadTimeout
    raise TimeoutError, "Request timed out after #{@timeout}s"
  end

  def prepare_http_request(stream)
    base_url = ENV.fetch('LLM_BASE_URL')
    uri = URI.parse("#{base_url}/chat/completions")

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == 'https')
    http.read_timeout = @timeout
    http.open_timeout = 10

    request = Net::HTTP::Post.new(uri.path)
    request["Content-Type"] = "application/json"
    request["Authorization"] = "Bearer #{api_key}"

    body = build_request_body
    if stream
      request["Accept"] = "text/event-stream"
      body[:stream] = true
    end
    request.body = body.to_json

    [http, request]
  end

  def handle_blocking_response(http, request)
    response = http.request(request)

    case response.code.to_i
    when 200
      JSON.parse(response.body)
    when 429
      raise ApiError, "Rate limit exceeded"
    when 500..599
      raise ApiError, "Server error: #{response.code}"
    else
      raise ApiError, "API error: #{response.code} - #{response.body}"
    end
  rescue JSON::ParserError => e
    raise ApiError, "Invalid JSON response: #{e.message}"
  end

  def handle_stream_response(http, request, &block)
    http.request(request) do |response|
      unless response.code.to_i == 200
        raise ApiError, "API error: #{response.code} - #{response.body}"
      end

      buffer = ""
      response.read_body do |chunk|
        buffer += chunk

        while (line_end = buffer.index("\n"))
          line = buffer[0...line_end].strip
          buffer = buffer[(line_end + 1)..-1]

          next if line.empty?
          next unless line.start_with?("data: ")

          data = line[6..-1]
          next if data == "[DONE]"

          begin
            json = JSON.parse(data)
            if content = json.dig("choices", 0, "delta", "content")
              block.call(content)
            end
          rescue JSON::ParserError => e
            Rails.logger.warn("Failed to parse SSE chunk: #{e.message}")
          end
        end
      end
    end
  end

  def build_request_body
    messages = []
    messages << { role: "system", content: @system } if @system.present?

    if @images.present?
      user_content = []
      user_content << { type: "text", text: @prompt.to_s }
      @images.each do |img|
        user_content << { type: "image_url", image_url: { url: img } }
      end
      messages << { role: "user", content: user_content }
    else
      messages << { role: "user", content: @prompt }
    end

    body = {
      model: @model,
      messages: messages,
      temperature: @temperature,
      max_tokens: @max_tokens
    }

    # Some providers require modalities when sending images
    body[:modalities] = ["text", "image"] if @images.present?

    body
  end

  def api_key
    ENV.fetch('LLM_API_KEY') do
      raise LlmError, "LLM_API_KEY not configured"
    end
  end

  def normalize_images(images)
    return [] if images.blank?
    list = images.is_a?(Array) ? images.compact : [images].compact
    list.map(&:to_s).reject(&:blank?)
  end
end
