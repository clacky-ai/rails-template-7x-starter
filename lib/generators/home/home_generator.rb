class HomeGenerator < Rails::Generators::Base
  source_root File.expand_path('templates', __dir__)

  def generate_controller
    template "controller.rb.erb", "app/controllers/home_controller.rb"
  end

  def generate_concern
    template "home_static_concern.rb.erb", "app/controllers/concerns/home_static_concern.rb"
  end

  def generate_views
    empty_directory "app/views/home"
  end

  def generate_request_spec
    template "request_spec.rb.erb", "spec/requests/home_spec.rb"
  end

  def add_root_route
    route "root 'home#index'"
  end

  def show_instructions
    say "\n"
    say "Generation completed! Please note the following file needs to be created and edited manually:", :green
    say "  - app/views/home/static.html.erb( write this file if the models have not created yet)", :yellow
    say "  - app/views/home/index.html.erb( remove static.html.erb and write it later when all models are created, navbar should be written in `app/views/shared/_navbar.html.erb`)", :yellow
    say "\n"
  end
end
