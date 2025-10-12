module AuthenticationHelpers
  def sign_in_as(user)
    post sign_in_path, params: {
      user: {
        email: user.email,
        password: user.password
      }
    }
  end

  def sign_in_system(user)
    # For system tests - finds submit button regardless of text/translation
    visit sign_in_path
    fill_in 'user[email]', with: user.email
    fill_in 'user[password]', with: user.password
    find('button[type="submit"]').click
  end

  def current_user
    return nil unless cookies.signed[:session_token]

    session = Session.find_by(id: cookies.signed[:session_token])
    session&.user
  end

  def sign_out
    delete sign_out_path
  end

end

RSpec.configure do |config|
  config.include AuthenticationHelpers, type: :request
  config.include AuthenticationHelpers, type: :feature
  config.include AuthenticationHelpers, type: :system
end
