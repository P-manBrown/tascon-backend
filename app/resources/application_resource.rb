class ApplicationResource
  include Alba::Resource

  def select(_key, value)
    !value.nil?
  end
end
