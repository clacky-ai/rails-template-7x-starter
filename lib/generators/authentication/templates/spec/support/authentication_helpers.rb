module AuthenticationHelpers
  def sign_in_as(user)
    post sign_in_path, params: {
      email: user.email,
      password: user.password
    }
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
end
