if Rails.env.development? || Rails.env.test?
  namespace :dev do
    desc "Generate authentication token for curl testing"
    task :token, [:email] => :environment do |t, args|
      email = args[:email] || "test@example.com"

      # Find existing user (skip password check in dev environment)
      if user = User.find_by(email: email)
        session = user.sessions.create!
        STDERR.puts "Token: #{session.id} (reused user: #{user.email})"
        STDERR.puts "curl -H 'Authorization: Bearer #{session.id}' http://localhost:3000/endpoint"
        puts session.id
        next
      end

      # User doesn't exist, create new one with default password
      user = User.new(
        email: email,
        name: "Test User",
        password: "password123",
        password_confirmation: "password123"
      )

      if user.save
        session = user.sessions.create!
        STDERR.puts "Token: #{session.id} (created new user: #{user.email})"
        STDERR.puts "curl -H 'Authorization: Bearer #{session.id}' http://localhost:3000/endpoint"
        puts session.id
      else
        STDERR.puts "❌ Failed to create test user:"
        STDERR.puts "   #{user.errors.full_messages.join(', ')}"
        STDERR.puts ""
        STDERR.puts "💡 Your User model may have required fields."
        STDERR.puts "   Update spec/factories/users.rb or pass custom email:"
        STDERR.puts "   rails dev:token[custom@example.com]"
        exit 1
      end
    end
  end
end
