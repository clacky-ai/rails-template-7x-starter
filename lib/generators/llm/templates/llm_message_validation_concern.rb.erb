# LlmMessageValidationConcern for models storing LLM conversation messages
# Handles validation for role field and allows empty content for streaming scenarios
module LlmMessageValidationConcern
  extend ActiveSupport::Concern

  VALID_ROLES = %w[assistant system user].freeze

  included do
    # Validate role is one of the allowed values
    validates :role, presence: true, inclusion: {
      in: VALID_ROLES,
      message: "%%{value} is not a valid role. Must be one of: #{VALID_ROLES.join(', ')}"
    }

    # Content can be empty - in streaming mode, content may start empty and build up gradually
    validates :content, allow_blank: true, length: { maximum: 100_000 }

    # Scopes for querying
    scope :by_role, ->(role) { where(role: role) }
  end

  # Instance methods

  # Check if message is from assistant
  def assistant?
    role == 'assistant'
  end

  # Check if message is from user
  def user?
    role == 'user'
  end

  # Check if message is system message
  def system?
    role == 'system'
  end
end
