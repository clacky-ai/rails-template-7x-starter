# OmniAuth Builder Enhancement
# Extends provider method via monkey patch to automatically handle OAuth configuration logic

module OmniAuth
  class Builder
    # Save the original provider method
    alias_method :original_provider, :provider

    # Override provider method to add automatic OAuth configuration functionality
    def provider(klass, *args, **opts, &block)
      # Normalize options: merge positional hash (if any) with keyword opts
      positional_options = args.last.is_a?(Hash) ? args.pop : {}
      user_opts = positional_options.deep_merge(opts)

      # Check if it's a supported OAuth provider
      if clacky_env_provided? and oauth_provider?(klass)
        # Enhance OAuth provider configuration
        enhance_oauth_provider(klass, args, user_opts, &block)
      else
        # Use the original provider method (preserve call shape)
        original_provider(klass, *args, **user_opts, &block)
      end
    end

    private

    # Check if Clacky environment variables are provided
    def clacky_env_provided?
      ENV['CLACKY_AUTH_CLIENT_ID'].present? && ENV['CLACKY_AUTH_CLIENT_SECRET'].present? && ENV['CLACKY_AUTH_HOST'].present?
    end

    # Check if it's a supported OAuth provider
    def oauth_provider?(klass)
      oauth_providers = [:google_oauth2, :facebook, :twitter2, :github]
      oauth_providers.include?(klass.to_sym)
    end

    # Enhance OAuth provider configuration
    def enhance_oauth_provider(klass, args, user_opts = {}, &block)
      # Apply Clacky Auth fallback logic
      client_id, client_secret = args[0], args[1]

      # Build final options
      enhanced_opts = build_provider_options(klass, user_opts, client_id)

      # Call original provider method
      original_provider(klass, client_id, client_secret, **enhanced_opts, &block)
    end

    # Build provider options
    def build_provider_options(klass, base_opts, client_id)
      opts = base_opts.dup

      # Check if using Clacky Auth
      if using_clacky_auth?(client_id)
        # Deep merge so nested hashes like client_options are merged instead of overwritten
        opts = opts.deep_merge(clacky_auth_options(klass, client_id))
      end

      opts
    end

    # Check if using Clacky Auth
    def using_clacky_auth?(client_id)
      clacky_auth_client_id = ENV['CLACKY_AUTH_CLIENT_ID']
      client_id == clacky_auth_client_id
    end

    # Get Clacky Auth options configuration
    def clacky_auth_options(klass, client_id)
      clacky_auth_host = ENV['CLACKY_AUTH_HOST']
      provider_path = provider_oauth_path(klass)

      opts = {
        client_options: {
          authorize_url: "#{clacky_auth_host}/oauth2/#{provider_path}/auth",
          token_url: "#{clacky_auth_host}/oauth2/#{provider_path}/token"
        }
      }

      # Special handling for Google: skip JWT verification
      if klass.to_sym == :google_oauth2
        opts[:skip_jwt] = true
      end

      opts
    end

    # Get provider path in Clacky Auth
    def provider_oauth_path(klass)
      case klass.to_sym
      when :google_oauth2
        'google'
      when :twitter2
        'x'
      when :facebook
        'facebook'
      when :github
        'github'
      else
        klass.to_s
      end
    end
  end
end
