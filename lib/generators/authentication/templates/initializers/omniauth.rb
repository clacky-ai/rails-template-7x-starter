Rails.application.config.middleware.use OmniAuth::Builder do
  # OAuth providers - only enabled if OAUTH_ENABLED is true

  if ENV['GOOGLE_OAUTH_ENABLED'] == 'true'
    provider :google_oauth2, ENV['GOOGLE_CLIENT_ID'], ENV['GOOGLE_CLIENT_SECRET'], {
      scope: 'email,profile',
      prompt: 'select_account',
      image_aspect_ratio: 'square',
      image_size: 50
    }
  end

  if ENV['FACEBOOK_OAUTH_ENABLED'] == 'true'
    provider :facebook, ENV['FACEBOOK_APP_ID'], ENV['FACEBOOK_APP_SECRET'], {
      scope: 'email,public_profile',
      info_fields: 'name,email'
    }
  end

  if ENV['TWITTER_OAUTH_ENABLED'] == 'true'
    provider :twitter2, ENV['TWITTER_API_KEY'], ENV['TWITTER_API_SECRET'], {
      scope: "tweet.read users.read"
    }
  end

  if ENV['GITHUB_OAUTH_ENABLED'] == 'true'
    provider :github, ENV['GITHUB_CLIENT_ID'], ENV['GITHUB_CLIENT_SECRET'], {
      scope: 'user:email'
    }
  end

  # Development provider (only in development)
  provider :developer unless Rails.env.production?
end
