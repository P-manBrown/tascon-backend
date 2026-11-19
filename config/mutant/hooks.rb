# Load every constant under app/ before mutant matches subjects, because the
# test environment loads lazily outside CI.
hooks.register(:env_infection_post) do
  Rails.application.eager_load!
end
