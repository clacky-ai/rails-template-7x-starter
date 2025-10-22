class LlmStreamJob < ApplicationJob
  queue_as :llm

  # Retry strategy configuration
  retry_on Net::ReadTimeout, wait: 5.seconds, attempts: 3
  retry_on LlmService::TimeoutError, wait: 5.seconds, attempts: 3
  retry_on LlmService::ApiError, wait: 10.seconds, attempts: 2

  discard_on ActiveJob::DeserializationError

  # Streaming LLM responses via ActionCable
  # Usage: LlmStreamJob.perform_later(chat_id: 123, prompt: "Hello")
  #
  # CRITICAL: ALL broadcasts MUST have 'type' field (auto-routes to client handler)
  # - type: 'chunk' → client calls handleChunk(data)
  # - type: 'done' → client calls handleDone(data)
  #
  # ⚠️  DO NOT rescue exceptions here!
  # ApplicationJob handles all exceptions globally and reports them automatically.
  # If you catch exceptions here, they will be "swallowed" and not reported.
  #
  # Example implementation:
  #   def perform(chat_id:, prompt:, system: nil, **options)
  #     full_content = ""
  #
  #     LlmService.call(prompt: prompt, system: system, **options) do |chunk|
  #       full_content += chunk
  #       ActionCable.server.broadcast("chat_#{chat_id}", {
  #         type: 'chunk',
  #         chunk: chunk
  #       })
  #     end
  #
  #     ActionCable.server.broadcast("chat_#{chat_id}", {
  #       type: 'done',
  #       content: full_content
  #     })
  #   end
  def perform(*args)
    # TODO: Implement streaming logic here
    raise 'Not Implement job here'
  end
end
