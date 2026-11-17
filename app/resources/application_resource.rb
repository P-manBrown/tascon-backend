class ApplicationResource
  include Alba::Resource

  # Alba calls this method by this name, so it keeps a non-predicate name.
  def select(_key, value) # rubocop:disable Naming/PredicateMethod
    !value.nil?
  end
end
