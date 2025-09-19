module DevelopmentCsrfBypassConcern
  extend ActiveSupport::Concern

  included do
    # Only skip csrf in development, make curl easy
    if Rails.env.development?
      skip_before_action :verify_authenticity_token, raise: false
    end
  end
end
