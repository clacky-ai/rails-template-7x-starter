class ControllerGenerator < Rails::Generators::NamedBase
  source_root File.expand_path('templates', __dir__)

  argument :actions, type: :array, default: [], banner: "action action"

  class_option :auth, type: :boolean, default: false, desc: "Generate controller with authentication required"
  class_option :single, type: :boolean, default: false, desc: "Generate singular resource (resource instead of resources)"

  def check_controller_conflicts
    return if options[:force_override]
    
    if protected_controller_names.include?(plural_name)
      say "Error: Cannot generate controller for '#{plural_name}' as it conflicts with authentication system.", :red
      say "The following controller names are protected:", :yellow
      protected_controller_names.each { |name| say "  - #{name}", :yellow }
      say "\nSolutions:", :blue
      say "1. Choose a different controller name to avoid conflicts", :blue
      say "2. Use a different name for your controller", :blue
      exit(1)
    end
  end

  def check_single_resource_actions
    if options[:single] && selected_actions.include?('index')
      say "Error: Singular resources cannot have 'index' action.", :red
      say "Singular resources (--single) represent a single resource instance.", :yellow
      say "Valid actions for singular resources: show, new, edit", :blue
      say "Remove 'index' from actions or remove --single flag.", :blue
      exit(1)
    end
  end

  def generate_controller
    check_controller_conflicts
    check_single_resource_actions
    template "controller.rb.erb", "app/controllers/#{plural_name}_controller.rb"
  end

  def generate_request_spec
    template "request_spec.rb.erb", "spec/requests/#{plural_name}_spec.rb"
  end

  def add_routes
    if options[:single]
      route "resource :#{singular_name}#{route_options}"
    else
      route "resources :#{plural_name}#{route_options}"
    end
  end

  def show_completion_message
    say "\n"
    say "Controller and tests generated successfully!", :green
    say "📄 No views generated - please create views manually:", :yellow
    say "\n"
    
    selected_actions.each do |action|
      case action
      when 'index'
        say "  app/views/#{plural_name}/index.html.erb", :blue unless options[:single]
      when 'show'
        if options[:single]
          say "  app/views/#{plural_name}/show.html.erb", :blue
        else
          say "  app/views/#{plural_name}/show.html.erb", :blue
        end
      when 'new'
        say "  app/views/#{plural_name}/new.html.erb", :blue
      when 'edit'
        say "  app/views/#{plural_name}/edit.html.erb", :blue
      end
    end
    
    say "\n"
    if options[:single]
      say "Tip: This is a singular resource - routes don't need :id parameter", :cyan
    end
  end

  private


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
      if options[:single]
        %w[show new edit]  # 单一资源不包含 index
      else
        %w[index show new edit]
      end
    else
      actions
    end
  end

  def requires_authentication?
    options[:auth]
  end

  def single_resource?
    options[:single]
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
