module ApplicationCable
  class Connection < ActionCable::Connection::Base
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
        token = auth_header.gsub(/Bearer\s+/, '')
        if session_record = Session.find_by(id: token)
          session_record.user
        else
          reject_unauthorized_connection
        end
      else
        reject_unauthorized_connection
      end
    end
  end
end
