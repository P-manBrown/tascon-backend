source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby "3.2.2"

gem "rails", "~> 7.0.4"

gem "mysql2", "~> 0.5"

gem "puma", "~> 6.2"

gem "tzinfo-data", platforms: %i[mingw mswin x64_mingw jruby]

gem "bootsnap", require: false

gem "rack-cors", "~> 2.0"

gem "rails-i18n", "~> 7.0"

gem "devise_token_auth", "~> 1.2"

gem "omniauth-google-oauth2"
gem "omniauth-rails_csrf_protection", "~> 1.0"
gem "omniauth-twitter", "~> 1.4"

group :development, :test do
  gem "dotenv-rails", "~> 2.8"

  gem "factory_bot_rails", "~> 6.2"

  gem "faker", "~> 3.1"

  gem "rspec-rails", "~> 6.0"

  gem "debug", platforms: %i[mri mingw x64_mingw]
end

group :development do
  gem "git-lint", "~> 6.0", require: false

  gem "guard", "~> 2.18"
  gem "guard-rspec", "~> 4.7", require: false

  gem "lefthook", "~> 1.3", require: false

  gem "letter_opener_web", "~> 2.0"

  gem "mdl", "~> 0.12.0", require: false

  gem "rubocop", "~> 1.48", require: false
  gem "rubocop-performance", "~> 1.16", require: false
  gem "rubocop-rails", "~> 2.18", require: false
  gem "rubocop-rspec", "~> 2.19", require: false
end
