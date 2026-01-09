source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby "3.4.7"

gem "rails", "~> 8.1.2"

gem "mysql2", "~> 0.5"

gem "puma", "~> 7.1"

gem "tzinfo-data", platforms: %i[mingw mswin x64_mingw jruby]

gem "bootsnap", require: false

gem "rack-cors", "~> 3.0"

gem "image_processing", "~> 1.14"

gem "alba", "~> 3.10"

gem "active_storage_validations", "~> 3.0"

gem "devise-i18n", "~> 1.15"
gem "devise_token_auth", "~> 1.2"

gem "omniauth-google-oauth2"
gem "omniauth-twitter", "~> 1.4"

gem "pagy", "~> 9.4"

gem "rails-i18n", "~> 8.1"

group :development, :test do
  gem "bullet", "~> 8.1"

  gem "dotenv-rails", "~> 3.2"

  gem "factory_bot_rails", "~> 6.5"

  gem "faker", "~> 3.5"

  gem "rspec-rails", "~> 8.0"

  gem "debug", platforms: %i[mri mingw x64_mingw]
end

group :development do
  gem "debride", "~> 1.15", require: false

  gem "guard", "~> 2.19"
  gem "guard-rspec", "~> 4.7", require: false

  gem "htmlbeautifier", "~> 1.4", require: false

  gem "lefthook", "~> 2.0", require: false

  gem "letter_opener_web", "~> 3.0"

  gem "rubocop", "~> 1.82", require: false
  gem "rubocop-erb", "~> 0.7.0", require: false
  gem "rubocop-factory_bot", "~> 2.28", require: false
  gem "rubocop-performance", "~> 1.26", require: false
  gem "rubocop-rails", "~> 2.34", require: false
  gem "rubocop-rspec", "~> 3.9", require: false
end
