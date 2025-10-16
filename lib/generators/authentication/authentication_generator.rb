class AuthenticationGenerator < Rails::Generators::Base
  include Rails::Generators::Migration
  source_root File.expand_path('templates', __dir__)

  desc "Generate a complete authentication system with users and sessions"

  def check_if_already_generated
    session_model = 'app/models/session.rb'
    current_model = 'app/models/current.rb'

    if File.exist?(session_model) && File.exist?(current_model)
      say "\n" + "="*70, :red
      say "ERROR: Authentication system has already been generated!", :red
      say "="*70, :red
      say "\nIncluded features:", :green
      say "  - User registration, login, password reset", :cyan
      say "  - Email verification", :cyan
      say "  - Session management", :cyan
      say "  - OAuth integration (Google, Facebook, Twitter, GitHub)", :cyan
      say "\nTo enable OAuth providers, set these in config/application.yml:", :yellow
      say "  GOOGLE_OAUTH_ENABLED: 'true'     # + GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET", :yellow
      say "  FACEBOOK_OAUTH_ENABLED: 'true'   # + FACEBOOK_APP_ID, FACEBOOK_APP_SECRET", :yellow
      say "  TWITTER_OAUTH_ENABLED: 'true'    # + TWITTER_API_KEY, TWITTER_API_SECRET", :yellow
      say "  GITHUB_OAUTH_ENABLED: 'true'     # + GITHUB_CLIENT_ID, GITHUB_CLIENT_SECRET", :yellow
      say "\n"
      exit(1)
    end
  end

  def create_models
    say "Creating models...", :green

    # User model
    copy_file 'models/user.rb', 'app/models/user.rb'

    # Session model
    copy_file 'models/session.rb', 'app/models/session.rb'

    # Current model
    copy_file 'models/current.rb', 'app/models/current.rb'
  end

  def create_controllers
    say "Creating controllers...", :green

    # Modify application controller with authentication methods
    add_authentication_to_application_controller

    # User authentication controllers
    copy_file 'controllers/sessions_controller.rb', 'app/controllers/sessions_controller.rb'
    copy_file 'controllers/registrations_controller.rb', 'app/controllers/registrations_controller.rb'
    copy_file 'controllers/passwords_controller.rb', 'app/controllers/passwords_controller.rb'

    # Identity namespace controllers
    copy_file 'controllers/identity/emails_controller.rb', 'app/controllers/identity/emails_controller.rb'
    copy_file 'controllers/identity/email_verifications_controller.rb', 'app/controllers/identity/email_verifications_controller.rb'
    copy_file 'controllers/identity/password_resets_controller.rb', 'app/controllers/identity/password_resets_controller.rb'

    # Omniauth controller
    copy_file 'controllers/sessions/omniauth_controller.rb', 'app/controllers/sessions/omniauth_controller.rb'

    # Invitations controller
    copy_file 'controllers/invitations_controller.rb', 'app/controllers/invitations_controller.rb'

    # Profiles controller
    copy_file 'controllers/profiles_controller.rb', 'app/controllers/profiles_controller.rb'

    # API controllers
    copy_file 'controllers/api/v1/sessions_controller.rb', 'app/controllers/api/v1/sessions_controller.rb'
  end

  def create_actioncable_authentication
    say "Adding ActionCable authentication...", :green
    add_authentication_to_actioncable_connection
  end

  def create_views
    say "Creating views...", :green

    # User authentication views
    copy_file 'views/sessions/show.html.erb', 'app/views/sessions/show.html.erb'
    copy_file 'views/sessions/new.html.erb', 'app/views/sessions/new.html.erb'
    copy_file 'views/sessions/devices.html.erb', 'app/views/sessions/devices.html.erb'
    copy_file 'views/registrations/new.html.erb', 'app/views/registrations/new.html.erb'
    copy_file 'views/passwords/edit.html.erb', 'app/views/passwords/edit.html.erb'

    # Identity views
    copy_file 'views/identity/emails/edit.html.erb', 'app/views/identity/emails/edit.html.erb'
    copy_file 'views/identity/password_resets/new.html.erb', 'app/views/identity/password_resets/new.html.erb'
    copy_file 'views/identity/password_resets/edit.html.erb', 'app/views/identity/password_resets/edit.html.erb'

    # Invitations views
    copy_file 'views/invitations/new.html.erb', 'app/views/invitations/new.html.erb'

    # Profile views
    copy_file 'views/profiles/show.html.erb', 'app/views/profiles/show.html.erb'
    copy_file 'views/profiles/edit.html.erb', 'app/views/profiles/edit.html.erb'
    copy_file 'views/profiles/edit_password.html.erb', 'app/views/profiles/edit_password.html.erb'
  end

  def create_mailers
    say "Creating mailers...", :green
    copy_file 'mailers/user_mailer.rb', 'app/mailers/user_mailer.rb'

    # Mailer views
    copy_file 'views/user_mailer/email_verification.html.erb', 'app/views/user_mailer/email_verification.html.erb'
    copy_file 'views/user_mailer/password_reset.html.erb', 'app/views/user_mailer/password_reset.html.erb'
    copy_file 'views/user_mailer/invitation_instructions.html.erb', 'app/views/user_mailer/invitation_instructions.html.erb'
  end

  def create_migrations
    say "Creating migrations...", :green

    # Generate timestamped migration files
    migration_template 'migrations/create_users.rb.erb', 'db/migrate/create_users.rb'
    sleep 0.01 # Ensure different timestamps
    migration_template 'migrations/create_sessions.rb.erb', 'db/migrate/create_sessions.rb'
  end

  def add_dependencies
    add_gems_to_gemfile
  end

  def add_routes
    say "Adding routes...", :green

    # Check if authentication routes are already present
    routes_file = File.read('config/routes.rb')
    if routes_file.include?('# Authentication routes generated by authentication generator')
      say "Authentication routes already exist, skipping...", :blue
      return
    end

    route_content = generate_routes_content

    # Insert routes at the beginning of the routes file
    inject_into_file 'config/routes.rb', after: "Rails.application.routes.draw do\n" do
      "  # Authentication routes generated by authentication generator\n" + route_content
    end
  end

  def add_omniauth_initializer
    say "Creating omniauth initializers...", :green
    copy_file 'initializers/omniauth.rb', 'config/initializers/omniauth.rb'
    copy_file 'initializers/omniauth_enhancements.rb', 'config/initializers/omniauth_enhancements.rb'
    add_oauth_config_to_application_yml
  end

  def create_tests
    say "Creating authentication tests...", :green

    # Create factory files
    copy_file 'spec/factories/users.rb', 'spec/factories/users.rb'
    copy_file 'spec/factories/sessions.rb', 'spec/factories/sessions.rb'

    # Create model tests
    copy_file 'spec/models/user_spec.rb', 'spec/models/user_spec.rb'

    # Create request tests
    copy_file 'spec/requests/authenticated_access_spec.rb', 'spec/requests/authenticated_access_spec.rb'

    # Create test helpers
    copy_file 'spec/support/authentication_helpers.rb', 'spec/support/authentication_helpers.rb'
  end

  def create_dev_tasks
    say "Creating development tasks...", :green
    copy_file 'lib/tasks/dev.rake', 'lib/tasks/dev.rake'
  end

  def add_oauth_config_to_application_yml
    say "Adding OAuth configuration to application.yml files...", :green

    oauth_config = <<~YAML

      # OAuth provider credentials generated by authentication generator
      # Set enabled: 'true' to activate each OAuth provider (use strings to avoid Figaro warnings)
      # Leave client id and secret blank to use Clacky Auth fallback

      # Google OAuth
      GOOGLE_OAUTH_ENABLED: 'false'
      GOOGLE_CLIENT_ID: '<%= ENV.fetch("CLACKY_AUTH_CLIENT_ID", "") %>'
      GOOGLE_CLIENT_SECRET: '<%= ENV.fetch("CLACKY_AUTH_CLIENT_SECRET", "") %>'

      # Facebook OAuth
      FACEBOOK_OAUTH_ENABLED: 'false'
      FACEBOOK_APP_ID: '<%= ENV.fetch("CLACKY_AUTH_CLIENT_ID", "") %>'
      FACEBOOK_APP_SECRET: '<%= ENV.fetch("CLACKY_AUTH_CLIENT_SECRET", "") %>'

      # Twitter OAuth
      TWITTER_OAUTH_ENABLED: 'false'
      TWITTER_API_KEY: '<%= ENV.fetch("CLACKY_AUTH_CLIENT_ID", "") %>'
      TWITTER_API_SECRET: '<%= ENV.fetch("CLACKY_AUTH_CLIENT_SECRET", "") %>'

      # GitHub OAuth
      GITHUB_OAUTH_ENABLED: 'false'
      GITHUB_CLIENT_ID: '<%= ENV.fetch("CLACKY_AUTH_CLIENT_ID", "") %>'
      GITHUB_CLIENT_SECRET: '<%= ENV.fetch("CLACKY_AUTH_CLIENT_SECRET", "") %>'
      # OAuth provider credentials generated end
    YAML

    # Add to application.yml.example if it exists and doesn't already have OAuth config
    if File.exist?('config/application.yml.example')
      file_content = File.read('config/application.yml.example')
      unless file_content.include?('# OAuth provider credentials generated by authentication generator')
        say "  Adding OAuth config to application.yml.example", :blue
        append_to_file 'config/application.yml.example', oauth_config
      else
        say "  OAuth config already generated in application.yml.example, skipping...", :yellow
      end
    end

    # Add to application.yml if it exists and doesn't already have OAuth config
    if File.exist?('config/application.yml')
      file_content = File.read('config/application.yml')
      unless file_content.include?('# OAuth provider credentials generated by authentication generator')
        say "  Adding OAuth config to application.yml", :blue
        append_to_file 'config/application.yml', oauth_config
      else
        say "  OAuth config already generated in application.yml, skipping...", :yellow
      end
    end

    unless File.exist?('config/application.yml.example') || File.exist?('config/application.yml')
      say "  No application.yml files found, skipping OAuth config", :yellow
    end
  end

  def add_gems_to_gemfile
    say "Adding required gems to Gemfile...", :green

    # Check if bcrypt is already in Gemfile (either active or commented)
    gemfile_content = File.read('Gemfile')

    # Handle bcrypt - uncomment if it exists as a comment, otherwise add it
    if gemfile_content.include?('# gem "bcrypt"')
      uncomment_lines 'Gemfile', /gem "bcrypt"/
    elsif !gemfile_content.include?('gem "bcrypt"') && !gemfile_content.include?("gem 'bcrypt'")
      gem 'bcrypt'
    end

    unless gemfile_content.include?('gem "omniauth"') || gemfile_content.include?("gem 'omniauth'")
      gem 'omniauth'
    end

    unless gemfile_content.include?('omniauth-rails_csrf_protection')
      gem 'omniauth-rails_csrf_protection'
    end

    # OAuth provider gems
    unless gemfile_content.include?('omniauth-google-oauth2')
      gem 'omniauth-google-oauth2'
    end

    unless gemfile_content.include?('omniauth-facebook')
      gem 'omniauth-facebook'
    end

    unless gemfile_content.include?('omniauth-twitter2')
      gem 'omniauth-twitter2'
    end

    unless gemfile_content.include?('omniauth-github')
      gem 'omniauth-github'
    end
  end

  def show_post_install_message
    say "\n" + "="*50, :green
    say "Authentication system generated successfully!", :green
    say "="*50, :green
    say "\nNext steps:", :yellow
    say "1. Run: bundle install (new OAuth gems added)"
    say "2. Run: rails db:migrate"
    say "3. OAuth login (Google, Facebook, Twitter, GitHub) is built-in:"
    say "   - Set *_OAUTH_ENABLED: 'true' in config/application.yml to enable"
    say "   - Default credentials are pre-configured and ready to use"
    say "   - DO NOT modify CLIENT_ID/CLIENT_SECRET unless user specifies it"
  end

  private

  def add_authentication_to_application_controller
    # Check if authentication code is already present
    app_controller_content = File.read('app/controllers/application_controller.rb')
    if app_controller_content.include?('# Authentication methods generated by authentication generator')
      say "Authentication methods already exist in ApplicationController, skipping...", :blue
      return
    end

    # Add before_action callbacks and helper_method at the beginning of the class
    inject_into_class 'app/controllers/application_controller.rb', 'ApplicationController' do
      <<-RUBY
  # Authentication methods generated by authentication generator
  before_action :set_current_request_details

  helper_method :current_user, :user_signed_in?
  # Authentication public methods generated end

      RUBY
    end

    # Add private authentication methods at the end, before the last 'end'
    gsub_file 'app/controllers/application_controller.rb', /^end\s*$/ do |match|
      <<-RUBY

  # Authentication private methods begin
  private

  def current_user
    Current.session&.user
  end

  def user_signed_in?
    current_user.present?
  end

  def authenticate_user!
    if session_record = find_session_record
      Current.session = session_record
    else
      redirect_to sign_in_path
    end
  end

  alias_method :authenticate, :authenticate_user!

  def set_current_request_details
    Current.user_agent = request.user_agent
    Current.ip_address = request.ip

    if session_record = find_session_record
      Current.session = session_record
    end
  end

  def find_session_record
    # Try cookie-based authentication first
    if cookies.signed[:session_token].present?
      return Session.find_by_id(cookies.signed[:session_token])
    end

    # Try Authorization header authentication
    if request.headers['Authorization'].present?
      token = request.headers['Authorization'].gsub(/Bearer\s+/, '')
      return Session.find_by_id(token)
    end

    nil
  end

  def handle_password_errors(user)
    error_messages = []

    user.errors.each do |error|
      case error.attribute
      when :current_password
        error_messages << "Current password is incorrect"
      when :password
        if error.type == :too_short
          error_messages << "New password must be at least \#{User::MIN_PASSWORD} characters long"
        elsif error.type == :invalid
          error_messages << "Password format is invalid"
        else
          error_messages << "New password: \#{error.message}"
        end
      when :password_confirmation
        error_messages << "Password confirmation doesn't match"
      when :password_digest
        error_messages << "Password format is invalid"
      end
    end

    if error_messages.empty?
      error_messages = user.errors.full_messages
    end

    return error_messages.first
  end

  # Authentication private methods end
#{match}
      RUBY
    end
  end

  def self.next_migration_number(dirname)
    next_migration_number = current_migration_number(dirname) + 1
    [Time.now.utc.strftime("%Y%m%d%H%M%S"), "%.14d" % next_migration_number].max
  end

  def generate_routes_content
    <<-RUBY
  get  "sign_in", to: "sessions#new"
  post "sign_in", to: "sessions#create"
  delete 'sign_out', to: 'sessions#destroy', as: :sign_out
  get  "sign_up", to: "registrations#new"
  post "sign_up", to: "registrations#create"
  resource :session, only: [:new, :show, :destroy] do
    get :devices, on: :member
    delete :destroy_one, on: :member
  end
  resources :registrations, only: [:new, :create]
  resource  :password, only: [:edit, :update]

  namespace :identity do
    resource :email,              only: [:edit, :update]
    resource :email_verification, only: [:show, :create]
    resource :password_reset,     only: [:new, :edit, :create, :update]
  end

  get  "/auth/failure",            to: "sessions/omniauth#failure"
  get  "/auth/:provider/callback", to: "sessions/omniauth#create"
  post "/auth/:provider/callback", to: "sessions/omniauth#create"

  resource :invitation, only: [:new, :create]

  # Profile routes
  resource :profile, only: [:show, :edit, :update], controller: 'profiles' do
    member do
      get :edit_password
      patch :update_password
    end
  end

  # API routes for curl-friendly authentication
  namespace :api do
    namespace :v1 do
      post 'login', to: 'sessions#login'
      delete 'logout', to: 'sessions#destroy'
    end
  end

  # Authentication routes generated end

    RUBY
  end

  def add_authentication_to_actioncable_connection
    connection_file = 'app/channels/application_cable/connection.rb'

    # Check if authentication code is already present
    if File.exist?(connection_file)
      connection_content = File.read(connection_file)
      if connection_content.include?('# Authentication methods generated by authentication generator')
        say "Authentication methods already exist in ActionCable Connection, skipping...", :blue
        return
      end
    end

    # Check if the connection file exists
    unless File.exist?(connection_file)
      say "ActionCable connection file not found, creating basic connection...", :yellow
      # Create directory if it doesn't exist
      FileUtils.mkdir_p(File.dirname(connection_file))
      # Create a basic connection file
      create_file connection_file, basic_connection_content
    end

    # Check if it already has a connect method
    connection_content = File.read(connection_file)
    if connection_content.include?('# Authentication methods generated by authentication generator')
      say "Authentication methods generated, skip add authentication logic", :yellow
    else
      # Add connect method and authentication logic
      inject_into_class connection_file, 'Connection' do
        <<-RUBY
    # Authentication methods generated by authentication generator
    identified_by :current_user

    def connect
      self.current_user = find_verified_user
    end

    private

    def find_verified_user
      # Try to authenticate via session token from cookies
      if session_token = cookies.signed[:session_token]
        if session_record = Session.find_by(id: session_token)
          session_record.user
        else
          reject_unauthorized_connection
        end
      # Try to authenticate via Authorization header (for API clients)
      elsif auth_header = request.headers['Authorization']
        token = auth_header.gsub(/Bearer\\s+/, '')
        if session_record = Session.find_by(id: token)
          session_record.user
        else
          reject_unauthorized_connection
        end
      else
        reject_unauthorized_connection
      end
    end
    # Authentication methods generated end

        RUBY
      end
    end
  end

  def basic_connection_content
    <<-RUBY
module ApplicationCable
  class Connection < ActionCable::Connection::Base
  end
end
    RUBY
  end
end
