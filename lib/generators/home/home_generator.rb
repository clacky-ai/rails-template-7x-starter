class HomeGenerator < Rails::Generators::Base
  source_root File.expand_path('templates', __dir__)

  def generate_controller
    template "controller.rb.erb", "app/controllers/home_controller.rb"
  end

  def generate_request_spec
    template "request_spec.rb.erb", "spec/requests/home_spec.rb"
  end

  def add_root_route
    route "root 'home#index'"
  end
end
