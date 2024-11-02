source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby "3.3.5"

gem "rails", "~> 7.2.2"

gem "mysql2", "~> 0.5"

gem "puma", "~> 6.4"

gem "tzinfo-data", platforms: %i[mingw mswin x64_mingw jruby]

gem "bootsnap", require: false

gem "rack-cors", "~> 2.0"

gem "image_processing", "~> 1.13"

gem "alba", "~> 3.3"

gem "active_storage_validations", "~> 1.2"

gem "devise-i18n", "~> 1.12"
gem "devise_token_auth", "~> 1.2"

gem "omniauth-google-oauth2"
gem "omniauth-rails_csrf_protection", "~> 1.0"
gem "omniauth-twitter", "~> 1.4"

gem "rails-i18n", "~> 7.0"

group :development, :test do
  gem "bullet", "~> 7.2"

  gem "dotenv-rails", "~> 3.1"

  gem "factory_bot_rails", "~> 6.4"

  gem "faker", "~> 3.5"

  gem "rspec-rails", "~> 7.0"

  gem "debug", platforms: %i[mri mingw x64_mingw]
end

group :development do
  gem "debride", "~> 1.12", require: false

  gem "guard", "~> 2.18"
  gem "guard-rspec", "~> 4.7", require: false

  gem "htmlbeautifier", "~> 1.4", require: false

  gem "lefthook", "~> 1.8", require: false

  gem "letter_opener_web", "~> 3.0"

  gem "rubocop", "~> 1.67", require: false
  gem "rubocop-erb", "~> 0.5.4", require: false
  gem "rubocop-factory_bot", "~> 2.26", require: false
  gem "rubocop-performance", "~> 1.22", require: false
  gem "rubocop-rails", "~> 2.27", require: false
  gem "rubocop-rspec", "~> 3.1", require: false
end
