module DateRangeFilter
  extend ActiveSupport::Concern

  private
    def parse_date_range
      return nil unless date_params_present?

      start_date = parse_date(params[:start], "start")
      end_date = parse_date(params[:end], "end")
      return nil if start_date.nil? || end_date.nil?

      if start_date > end_date
        render_invalid_date_range_error
        return nil
      end

      [start_date, end_date]
    end

    def date_params_present?
      if params[:start].blank?
        render_missing_start_param_error
        return false
      end

      if params[:end].blank?
        render_missing_end_param_error
        return false
      end

      true
    end

    def parse_date(date_string, param_name)
      Date.parse(date_string)
    rescue Date::Error
      render_custom_error source: param_name, type: "invalid",
                          message: "'#{param_name}' は YYYY-MM-DD 形式で指定してください。"
      nil
    end

    def render_missing_start_param_error
      render_custom_error source: "start", type: "required", message: "'start' パラメータは必須です。"
    end

    def render_missing_end_param_error
      render_custom_error source: "end", type: "required", message: "'end' パラメータは必須です。"
    end

    def render_invalid_date_range_error
      render_custom_error source: "end", type: "invalid", message: "'end' は 'start' より後の日付を指定してください。"
    end
end
