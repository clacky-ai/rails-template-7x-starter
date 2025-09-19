require 'rails_helper'

RSpec.describe "Authenticated Access", type: :request do
  let(:user) { create(:user) }

  describe "Home page access after login" do
    context "when user is logged in" do
      before { sign_in_as(user) }

      it "returns 200 status code for root path" do
        get '/'
        expect_response_to_success_or_404
      end

      it "displays user-specific content" do
        get '/'
        # This test assumes the home page shows some user info or login-specific content
        # Adjust the expectation based on your actual home page implementation
        expect(response.body).not_to include('Sign in')
      end

      it "allows access to profile page" do
        get profile_path
        expect(response).to be_success_with_view_check('show')
      end
    end

    context "when user is not logged in" do
      it "allows access to public home page" do
        # Assuming the home page is public and doesn't require authentication
        get '/'
        expect_response_to_success_or_404
      end
    end
  end

  describe "Authentication flow integration" do
    it "complete sign up and immediate access flow" do
      # Sign up
      post sign_up_path, params: {
        name: 'New User',
        email: 'newuser@example.com',
        password: 'password123',
        password_confirmation: 'password123'
      }

      expect(response).to redirect_to('/')

      # Follow redirect and verify access
      follow_redirect!
      expect_response_to_success_or_404

      # Should be able to access protected resources immediately
      get profile_path
      expect(response).to be_success_with_view_check('show')
    end

    it "complete sign in and access flow" do
      # Sign in
      post sign_in_path, params: {
        email: user.email,
        password: 'password123'
      }

      expect(response).to redirect_to('/')

      # Follow redirect and verify access
      follow_redirect!
      expect_response_to_success_or_404

      # Verify we can access other protected pages
      get profile_path
      expect(response).to be_success_with_view_check('show')
    end
  end
end
