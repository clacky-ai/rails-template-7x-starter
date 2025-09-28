class ControllerGenerator < Rails::Generators::NamedBase
  source_root File.expand_path('templates', __dir__)

  argument :actions, type: :array, default: [], banner: "action action"

  class_option :auth, type: :boolean, default: false, desc: "Generate controller with authentication required"
  class_option :single, type: :boolean, default: false, desc: "Generate singular resource (resource instead of resources)"

  def check_name_validity
    # Check for reserved words first (before processing)
    if %w[controller controllers].include?(name.downcase)
      say "Error: Cannot generate controller with name '#{name}'.", :red
      say "This name is reserved. Please choose a different name.", :yellow
      say "Example: rails generate controller products", :blue
      exit(1)
    end

    # Check for empty or invalid names after processing
    if base_name_without_controller.blank?
      say "Error: Controller name cannot be empty after processing.", :red
      say "Usage: rails generate controller NAME [actions]", :yellow
      say "Example: rails generate controller products", :blue
      exit(1)
    end

    # Check for minimum length (at least 2 characters)
    if base_name_without_controller.length < 2
      say "Error: Controller name must be at least 2 characters long.", :red
      say "Single letter controller names can cause naming conflicts.", :yellow
      say "Example: rails generate controller posts", :blue
      exit(1)
    end
  end

  def check_controller_conflicts
    return if options[:force_override]

    check_name_validity

    # Special check for home controller
    if singular_name == 'home' || plural_name == 'home'
      say "Error: Cannot generate 'home' controller - it already exists in the system.", :red
      say "💡 To add home page functionality:", :blue
      say "   Create and edit app/views/home/index.html.erb directly", :blue
      say "\n⚠️  Important: Write real business logic, do not reference any demo files", :yellow
      exit(1)
    end

    if protected_controller_names.include?(plural_name)
      conflict_reason = case plural_name
                       when 'tmp', 'tmps'
                         "as it conflicts with development middleware and temporary file system"
                       else
                         "as it conflicts with authentication system"
                       end
      
      say "Error: Cannot generate controller for '#{plural_name}' #{conflict_reason}.", :red
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

  def create_view_directories
    # Create the view directory for the controller
    empty_directory "app/views/#{plural_name}"
  end

  def add_routes
    if behavior == :invoke
      # Creating routes
      if options[:single]
        if route_options.nil?
          # Has custom actions, use do-end block
          route_with_custom_actions("resource :#{singular_name}")
        else
          add_simple_route("resource :#{singular_name}#{route_options}")
        end
      else
        if route_options.nil?
          # Has custom actions, use do-end block
          route_with_custom_actions("resources :#{plural_name}")
        else
          add_simple_route("resources :#{plural_name}#{route_options}")
        end
      end
    else
      # Destroying routes
      remove_routes
    end
  end

  def show_completion_message
    say "\n"
    say "Controller, tests and view directory generated successfully!", :green
    say "📁 View directory created: app/views/#{plural_name}/", :green
    say "📄 Please create and edit view files manually as needed:", :yellow
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

  def base_name_without_controller
    # Remove '_controller' or '_controllers' suffix if present (case insensitive)
    name.gsub(/_?controllers?$/i, '')
  end

  def singular_name
    base_name_without_controller.underscore.singularize
  end

  def plural_name
    base_name_without_controller.underscore.pluralize
  end

  def class_name
    base_name_without_controller.classify
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
      omniauths
      orders
      tmps
    ]
  end

  def controller_actions
    actions_code = []

    # Add CRUD actions
    crud_actions_to_generate.each do |action|
      case action
      when 'index' then actions_code << index_action
      when 'show' then actions_code << show_action
      when 'new' then actions_code << new_action
      when 'create' then actions_code << create_action
      when 'edit' then actions_code << edit_action
      when 'update' then actions_code << update_action
      when 'destroy' then actions_code << destroy_action
      end
    end

    # Add non-CRUD actions
    non_crud_actions.each do |action|
      actions_code << custom_action(action)
    end

    actions_code.join("\n\n")
  end

  def route_options
    if actions.empty?
      ""
    elsif has_full_crud? && has_only_crud_actions?
      ""  # Full resources without only restriction and no custom actions
    elsif has_only_crud_actions?
      ", only: [:#{route_actions.join(', :')}]"
    else
      # Has custom actions, need do-end block
      nil  # Will be handled in add_routes method
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

  def custom_action(action_name)
    <<-ACTION
  def #{action_name}
    # Write your real logic here
  end
    ACTION
  end

  # Helper methods for route generation
  def crud_actions_to_generate
    actions = []

    # Include explicitly specified actions
    selected_actions.each do |action|
      case action
      when 'index', 'show', 'new', 'edit', 'create', 'update', 'destroy'
        actions << action
      end
    end

    # Auto-add paired actions only if not explicitly specified
    if selected_actions.include?('new') && !selected_actions.include?('create')
      actions << 'create'
    end

    if selected_actions.include?('edit') && !selected_actions.include?('update')
      actions << 'update'
    end

    # Only auto-add destroy if new or edit is present but destroy is not explicitly specified
    if selected_actions.any? { |action| %w[new edit].include?(action) } && !selected_actions.include?('destroy')
      actions << 'destroy'
    end

    actions.uniq
  end

  def non_crud_actions
    # HTTP methods and user-facing CRUD actions should not be in member blocks
    standard_actions = %w[index show new edit create update destroy]
    selected_actions.reject { |action| standard_actions.include?(action) }
  end

  def has_full_crud?
    return false if actions.empty?

    expected_crud = if options[:single]
      %w[show new edit create update destroy]
    else
      %w[index show new edit create update destroy]
    end

    # Check if all expected CRUD actions are present (allow additional custom actions)
    expected_crud.all? { |action| selected_actions.include?(action) }
  end

  def has_only_crud_actions?
    non_crud_actions.empty?
  end

  def route_actions
    actions = []

    selected_actions.each do |action|
      case action
      when 'index', 'show', 'new', 'edit', 'create', 'update', 'destroy'
        actions << action
      end
    end

    # Auto-add paired actions only if not explicitly specified
    if selected_actions.include?('new') && !selected_actions.include?('create')
      actions << 'create'
    end

    if selected_actions.include?('edit') && !selected_actions.include?('update')
      actions << 'update'
    end

    # Only auto-add destroy if new or edit is present but destroy is not explicitly specified
    if selected_actions.any? { |action| %w[new edit].include?(action) } && !selected_actions.include?('destroy')
      actions << 'destroy'
    end

    actions.uniq
  end

  def route_with_custom_actions(base_route)
    controller_name = options[:single] ? singular_name : plural_name
    route_lines = []

    # Add comment marker for identification
    route_lines << "  # Routes for #{controller_name} generated by controller generator"

    if route_actions.any? && !has_full_crud?
      # Has some CRUD actions but not all - include them with only
      route_lines << "  #{base_route}, only: [:#{route_actions.join(', :')}] do"
    else
      # Either no CRUD actions or has full CRUD - just the base route
      route_lines << "  #{base_route} do"
    end

    # Add custom actions as simple member routes
    if non_crud_actions.any?
      non_crud_actions.each do |action|
        route_lines << "    get :#{action}"
      end
    end

    route_lines << "  end"
    route_lines << "  # End routes for #{controller_name}"

    inject_into_file 'config/routes.rb', after: "Rails.application.routes.draw do\n" do
      route_lines.join("\n") + "\n\n"
    end
  end

  def add_simple_route(route_line)
    controller_name = options[:single] ? singular_name : plural_name

    route_content = [
      "  # Routes for #{controller_name} generated by controller generator",
      "  #{route_line}",
      "  # End routes for #{controller_name}",
      ""
    ].join("\n")

    inject_into_file 'config/routes.rb', after: "Rails.application.routes.draw do\n" do
      route_content + "\n"
    end
  end

  def remove_routes
    routes_file = File.join(destination_root, 'config/routes.rb')
    return unless File.exist?(routes_file)

    routes_content = File.read(routes_file)
    controller_name = options[:single] ? singular_name : plural_name

    # Look for routes using comment markers
    start_comment = "  # Routes for #{controller_name} generated by controller generator"
    end_comment = "  # End routes for #{controller_name}"

    if routes_content.include?(start_comment) && routes_content.include?(end_comment)
      # Remove section between comment markers (including the comments)
      pattern = /  # Routes for #{Regexp.escape(controller_name)} generated by controller generator.*?  # End routes for #{Regexp.escape(controller_name)}\n\n/m

      new_content = routes_content.gsub(pattern, '')
      File.write(routes_file, new_content)
      say "Removed routes for #{controller_name}", :green
    else
      say "Could not find marked routes for #{controller_name}. Please remove manually from config/routes.rb", :yellow
      say "Note: Routes generated by newer versions use comment markers for easier removal.", :blue
    end
  rescue => e
    say "Error removing routes: #{e.message}", :red
    say "Please manually remove routes for #{controller_name} from config/routes.rb", :yellow
  end

end
