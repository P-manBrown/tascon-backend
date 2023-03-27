# Temporary workaround for https://github.com/heartcombo/devise/issues/5443
require "devise/version"
raise "Consider removing this patch." unless Devise::VERSION == "4.9.0"

Rails.configuration.to_prepare do
  DeviseController.class_eval do
    before_action :set_fake_rack_session_for_devise
    # rubocop:disable Lint/ConstantDefinitionInBlock
    class FakeRackSession < Hash
      def enabled?
        false
      end

      def destroy; end
    end
    # rubocop:enable Lint/ConstantDefinitionInBlock

    private
      def set_fake_rack_session_for_devise
        if Rails.configuration.respond_to?(:api_only) \
            && Rails.configuration.api_only
          request.env["rack.session"] ||= FakeRackSession.new
        end
      end
  end
end
