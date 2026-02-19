module ErrorRendering
  extend ActiveSupport::Concern

  private
    def render_custom_error(source:, type:, message:, status: :unprocessable_entity)
      formatted_error = format_error_object(source: source, type: type, message: message)
      render json: { error: formatted_error }, status: status
    end

    def render_validation_error(errors)
      formatted_errors = errors.map do |error|
        format_error_object(
          source: error.attribute,
          type: error.type,
          message: error.full_message
        )
      end
      render json: { errors: formatted_errors }, status: :unprocessable_content
    end

    def format_error_object(source:, type:, message:)
      {
        source: source,
        type: type,
        message: message
      }
    end
end
