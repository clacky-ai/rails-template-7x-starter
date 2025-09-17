class CrudGenerator < Rails::Generators::NamedBase
  source_root File.expand_path('templates', __dir__)

  argument :actions, type: :array, default: [], banner: "action action"

  class_option :auth, type: :boolean, default: false, desc: "Generate controller with authentication required"

  def check_model_exists
    unless model_class_exists?
      say "Error: Model '#{class_name}' does not exist.", :red
      say "Please create the model first using: rails generate model #{class_name} [index show...]", :yellow
      exit(1)
    end
  end

  def check_controller_conflicts
    return if options[:force_override]
    
    if protected_controller_names.include?(plural_name)
      say "Error: Cannot generate CRUD for '#{plural_name}' as it conflicts with authentication system.", :red
      say "The following controller names are protected:", :yellow
      protected_controller_names.each { |name| say "  - #{name}", :yellow }
      say "\nSolutions:", :blue
      say "1. Choose a different model name to avoid conflicts", :blue
      say "2. Use `rails generate controller xxx` instead", :blue
      exit(1)
    end
  end

  def generate_controller
    check_controller_conflicts
    template "controller.rb.erb", "app/controllers/#{plural_name}_controller.rb"
  end

  def generate_request_spec
    template "request_spec.rb.erb", "spec/requests/#{plural_name}_spec.rb"
  end

  def add_routes
    route "resources :#{plural_name}#{route_options}"
  end

  private

  def model_class_exists?
    begin
      class_name.constantize
      true
    rescue NameError
      false
    end
  end

  def singular_name
    name.underscore.singularize
  end

  def plural_name
    name.underscore.pluralize
  end

  def class_name
    name.classify
  end


  def selected_actions
    if actions.empty?
      %w[index show new edit]
    else
      actions
    end
  end

  def requires_authentication?
    options[:auth]
  end

  def protected_controller_names
    %w[
      sessions
      registrations 
      passwords
      profiles
      invitations
      omniauth
      orders
    ]
  end

  def controller_actions
    actions_code = []

    if selected_actions.include?('index')
      actions_code << index_action
    end

    if selected_actions.include?('show')
      actions_code << show_action
    end

    if selected_actions.include?('new')
      actions_code << new_action
      actions_code << create_action
    end

    if selected_actions.include?('edit')
      actions_code << edit_action
      actions_code << update_action
    end

    if selected_actions.any? { |action| %w[new edit].include?(action) }
      actions_code << destroy_action
    end

    actions_code.join("\n\n")
  end


  def route_options
    if actions.empty?
      ""
    else
      ", only: [:#{selected_actions.join(', :')}#{', :create' if selected_actions.include?('new')}#{', :update' if selected_actions.include?('edit')}#{', :destroy' if selected_actions.any? { |a| %w[new edit].include?(a) }}]"
    end
  end

  def index_action
    <<-ACTION
  def index
    # Write your real logic here
  end
    ACTION
  end

  def show_action
    <<-ACTION
  def show
    # Write your real logic here
  end
    ACTION
  end

  def new_action
    <<-ACTION
  def new
    # Write your real logic here
  end
    ACTION
  end

  def create_action
    <<-ACTION
  def create
    # Write your real logic here
  end
    ACTION
  end

  def edit_action
    <<-ACTION
  def edit
    # Write your real logic here
  end
    ACTION
  end

  def update_action
    <<-ACTION
  def update
    # Write your real logic here
  end
    ACTION
  end

  def destroy_action
    <<-ACTION
  def destroy
    # Write your real logic here
  end
    ACTION
  end

end
