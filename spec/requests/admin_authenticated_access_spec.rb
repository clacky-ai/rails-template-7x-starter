require 'rails_helper'

RSpec.describe "Admin Authenticated Access", type: :request do
  let(:admin) { create(:administrator) }

  describe "Admin dashboard access after login" do
    context "when admin is logged in" do
      before { admin_sign_in_as(admin) }

      it "returns 200 status code for admin root path" do
        get admin_root_path
        expect(response).to be_success_with_view_check('index')
      end
    end

    context "when admin is not logged in" do
      it "redirects to admin login page" do
        get admin_root_path
        expect(response).to redirect_to(admin_login_path)
      end
    end
  end
end
