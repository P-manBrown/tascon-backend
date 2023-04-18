source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby "3.2.1"

gem "rails", "~> 7.0.4"

gem "mysql2", "~> 0.5"

gem "puma", "~> 6.2"

gem "tzinfo-data", platforms: %i[mingw mswin x64_mingw jruby]

gem "bootsnap", require: false

gem "rack-cors", "~> 2.0"

group :development, :test do
  gem "dotenv-rails", "~> 2.8"

  gem "factory_bot_rails", "~> 6.2"

  gem "rspec-rails", "~> 6.0.0"

  gem "debug", platforms: %i[mri mingw x64_mingw]
end

group :development do
  gem "guard", "~> 2.18"
  gem "guard-rspec", "~> 4.7", require: false

  gem "lefthook", "~> 1.3", require: false

  gem "mdl", "~> 0.12.0", require: false

  gem "rubocop", "~> 1.50", require: false
  gem "rubocop-performance", "~> 1.17", require: false
  gem "rubocop-rails", "~> 2.19", require: false
  gem "rubocop-rspec", "~> 2.20", require: false

  source "https://rubygems.pkg.github.com/p-manbrown" do
    gem "my_git-lint", "~> 1.0", require: false
  end
end
