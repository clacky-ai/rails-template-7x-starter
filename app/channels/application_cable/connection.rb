module ApplicationCable
  class Connection < ActionCable::Connection::Base
    # identified_by :session_id

    # We can access request/cookies object directly here
    # def connect
    #   self.session_id = request.session[:chat_session_id]
    # end
  end
end
