# frozen_string_literal: true

require "rails/generators/named_base"

module Noticed
  module Generators
    class WebPushGenerator < Rails::Generators::NamedBase
      include Rails::Generators::ResourceHelpers

      source_root File.expand_path("../templates", __FILE__)

      desc "Generates a Notification model for storing notifications."

      argument :name, type: :string, default: "WebPushSubscription", banner: "Asdfasd"
      argument :attributes, type: :array, default: [], banner: "field:type field:type"

      def add_web_push
        # gem "web-push", "~> 3.0"
      end

      def generate_web_push_subscription_model
        generate :model, name, "user:references endpoint auth_key p256dh_key", *attributes

        inject_into_file File.join("app", "models", "web_push_subscription.rb"), after: "belongs_to :user" do
          <<~PUBLISH

          
              def publish(data)
                WebPush.payload_send(
                  message: data.to_json,
                  endpoint: endpoint,
                  p256dh: p256dh_key,
                  auth: auth_key,
                  vapid: {
                    private_key: Rails.application.credentials.dig(:web_push, :private_key),
                    public_key: Rails.application.credentials.dig(:web_push, :public_key)
                  }
                )
              end
          PUBLISH
        end
      end

      def add_to_user
        inject_into_class File.join("app", "models", "user.rb"), "User", "  has_many :web_push_subscriptions, dependent: :destroy\n"
      end

      def add_controller
        template "web_push_subscriptions_controller.rb", "app/controllers/web_push_subscriptions_controller.rb"
        route "resources :web_push_subscriptions, only: :create"
      end

      def generate_vapid_keys
        puts <<~KEYS
        Add the following to your credentials (rails credentials:edit):"
        
        web_push:
          public_key: "#{vapid_key.public_key}"
          private_key: "#{vapid_key.private_key}"
        KEYS
      end

      def add_layout_header
        inject_into_file File.join("app", "views", "layouts", "application.html.erb"), before: "</head>" do
          "\n    <meta name=\"web_push_public\" content=\"<%= Base64.urlsafe_decode64(Rails.application.credentials.dig(:web_push, :public_key)).bytes %>\" />\n  "
        end
      end

      def setup_javscript
        template "web_push.js", "app/javascript/src/web_push.js"
        template "service_worker.js", "public/service_worker.js"

        append_to_file File.join("app", "javascript", "application.js") do
          "\nimport \"./src/web_push\"\n"
        end
      end

      def done
        readme "WEB_PUSH_README" if behavior == :invoke
      end

      private

      def model_path
        @model_path ||= File.join("app", "models", "#{file_path}.rb")
      end

      def vapid_key
        @vapid_key ||= WebPush.generate_key
      end

    end
  end
end

