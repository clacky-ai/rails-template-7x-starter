# frozen_string_literal: true

module Rails
  module Generators
    class PwaGenerator < Base
      source_root File.expand_path("templates", __dir__)

      class_option :theme_color, type: :string, default: nil, desc: "Theme color for PWA (defaults to --color-primary from application.css or #7c3aed)"
      class_option :skip_controller, type: :boolean, default: false, desc: "Skip creating Stimulus controller"
      class_option :skip_routes, type: :boolean, default: false, desc: "Skip adding routes"

      def create_pwa_controller
        template "pwa_controller.rb", "app/controllers/pwa_controller.rb"
      end

      def create_manifest
        template "manifest.json.erb", "app/views/pwa/manifest.json.erb"
      end

      def create_service_worker
        template "service_worker.js.erb", "app/views/pwa/service_worker.js.erb"
      end

      def create_stimulus_controller
        unless options[:skip_controller]
          template "pwa_install_controller.ts", "app/javascript/controllers/pwa_install_controller.ts"
          add_to_stimulus_index
        end
      end

      def add_routes
        unless options[:skip_routes]
          route_content = <<-RUBY
  # PWA routes
  get '/manifest.json', to: 'pwa#manifest', defaults: { format: :json }
  get '/service-worker.js', to: 'pwa#service_worker', defaults: { format: :js }
          RUBY

          inject_into_file "config/routes.rb", route_content, after: "Rails.application.routes.draw do\n"
        end
      end

      def add_layout_tags
        layout_file = "app/views/layouts/application.html.erb"
        if File.exist?(layout_file)
          content = File.read(layout_file)

          # Add manifest and meta tags in <head>
          unless content.include?("manifest.json")
            pwa_tags = <<~HTML
    <link rel="manifest" href="/manifest.json">
    <meta name="theme-color" content="#{theme_color}">
    <meta name="mobile-web-app-capable" content="yes">
    <meta name="apple-mobile-web-app-capable" content="yes">
    <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
            HTML

            inject_into_file layout_file, pwa_tags, after: /<meta name="viewport".*>\n/
          end

          # Add service worker registration script before </body>
          unless content.include?("serviceWorker.register")
            service_worker_script = <<~HTML
    <script>
      if ('serviceWorker' in navigator) {
        window.addEventListener('load', () => {
          navigator.serviceWorker.register('/service-worker.js')
            .then(registration => console.log('ServiceWorker registered:', registration.scope))
            .catch(error => console.error('ServiceWorker registration failed:', error));
        });
      }
    </script>
            HTML

            inject_into_file layout_file, service_worker_script, before: /\s*<\/body>/
          end
        end
      end

      def show_completion_message
        say "\n"
        say "✅ PWA setup completed!", :green
        say "\n"
        say "📱 Created files:", :blue
        say "   • app/controllers/pwa_controller.rb", :blue
        say "   • app/views/pwa/manifest.json.erb", :blue
        say "   • app/views/pwa/service_worker.js.erb", :blue
        unless options[:skip_controller]
          say "   • app/javascript/controllers/pwa_install_controller.ts", :blue
        end
        say "\n"
        say "🔧 Next steps:", :yellow
        say "   1. Customize manifest.json.erb with your app details", :yellow
        say "   2. Add app icons (192x192, 512x512) to app/assets/images/", :yellow
        say "   3. Update service_worker.js.erb cache strategy if needed", :yellow
        unless options[:skip_controller]
          say "   4. Add install button: <button data-controller=\"pwa-install\" data-action=\"click->pwa-install#install\" data-pwa-install-target=\"installButton\">Install App</button>", :yellow
        end
        say "\n"
        say "📖 Configuration:", :cyan
        say "   App name: #{app_name}", :cyan
        say "   Theme color: #{theme_color}", :cyan
        say "\n"
      end

      private

      def app_name
        @app_name ||= Rails.application.config.x.appname
      end

      def short_name
        @short_name ||= app_name.gsub(/\s+/, '')
      end

      def theme_color
        @theme_color ||= options[:theme_color] || extract_primary_color_from_css || "#7c3aed"
      end

      def cache_prefix
        @cache_prefix ||= app_name.downcase.gsub(/\s+/, '-')
      end

      # Extract --color-primary from application.css and convert to hex
      def extract_primary_color_from_css
        css_file = Rails.root.join('app/assets/stylesheets/application.css')
        return nil unless File.exist?(css_file)

        content = File.read(css_file)
        # Match --color-primary: 250 100% 65%;
        match = content.match(/--color-primary:\s*(\d+)\s+(\d+)%\s+(\d+)%/)
        return nil unless match

        h, s, l = match[1].to_i, match[2].to_i, match[3].to_i
        hsl_to_hex(h, s, l)
      end

      # Convert HSL to HEX color
      def hsl_to_hex(h, s, l)
        h = h / 360.0
        s = s / 100.0
        l = l / 100.0

        if s == 0
          r = g = b = l
        else
          q = l < 0.5 ? l * (1 + s) : l + s - l * s
          p = 2 * l - q
          r = hue_to_rgb(p, q, h + 1.0/3)
          g = hue_to_rgb(p, q, h)
          b = hue_to_rgb(p, q, h - 1.0/3)
        end

        "#%02x%02x%02x" % [(r * 255).round, (g * 255).round, (b * 255).round]
      end

      def hue_to_rgb(p, q, t)
        t += 1 if t < 0
        t -= 1 if t > 1
        return p + (q - p) * 6 * t if t < 1.0/6
        return q if t < 1.0/2
        return p + (q - p) * (2.0/3 - t) * 6 if t < 2.0/3
        p
      end

      def add_to_stimulus_index
        index_file = "app/javascript/controllers/index.ts"
        controller_class_name = "PwaInstallController"
        import_statement = "import #{controller_class_name} from \"./pwa_install_controller\""
        register_statement = "application.register(\"pwa-install\", #{controller_class_name})"

        if File.exist?(index_file)
          content = File.read(index_file)

          unless content.include?(import_statement)
            inject_into_file index_file, "#{import_statement}\n", after: /import.*_controller"\n(?=\n)/
            say_status :insert, "Added import to app/javascript/controllers/index.ts", :green
          end

          unless content.include?(register_statement)
            inject_into_file index_file, "#{register_statement}\n", after: /application\.register\(.*\)\n(?=\n)/
            say_status :insert, "Added registration to app/javascript/controllers/index.ts", :green
          end
        else
          say_status :error, "app/javascript/controllers/index.ts not found", :red
        end
      end
    end
  end
end
