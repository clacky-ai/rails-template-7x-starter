require 'rails_helper'

RSpec.describe "Authenticated Access", type: :request do
  let(:user) { create(:user) }

  describe "Home page access after login" do
    context "when user is logged in" do
      before { sign_in_as(user) }

      it "returns 200 or under development code for root path" do
        get root_path
        expect(response).to be_success_or_under_development
      end

      it "displays user-specific content" do
        get root_path
        # This test assumes the home page shows some user info or login-specific content
        # Adjust the expectation based on your actual home page implementation
        expect(response.body).not_to include('Sign in')
      end

      it "displays navbar with sign out link" do
        get root_path
        expect(response.body).to match(/<nav|data-navbar|class="navbar"/),
          "Navbar not found. Please update app/views/shared/_navbar.html.erb with navigation links"
      end

      it "allows access to profile page" do
        get profile_path
        expect(response).to have_http_status(:ok)
      end
    end

    context "when user is not logged in" do
      it "allows access to public home page" do
        # Assuming the home page is public and doesn't require authentication
        get root_path
        expect(response).to be_success_or_under_development
      end
    end
  end

  describe "Authentication flow integration" do
    it "complete sign up and immediate access flow" do
      # Sign up
      post sign_up_path, params: {
        user: {
          name: 'New User',
          email: 'newuser@example.com',
          password: 'password123',
          password_confirmation: 'password123'
        }
      }

      expect(response).to redirect_to(root_path)

      # Follow redirect and verify access
      follow_redirect!
      expect(response).to be_success_or_under_development

      # Should be able to access protected resources immediately
      get profile_path
      expect(response).to have_http_status(:ok)
    end

    it "complete sign in and access flow" do
      # Sign in
      post sign_in_path, params: {
        user: {
          email: user.email,
          password: user.password
        }
      }

      expect(response).to redirect_to(root_path)

      # Follow redirect and verify access
      follow_redirect!
      expect(response).to be_success_or_under_development

      # Verify we can access other protected pages
      get profile_path
      expect(response).to have_http_status(:ok)
    end
  end
end
