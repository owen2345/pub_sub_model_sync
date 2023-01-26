source "https://rubygems.org"

gem 'rubocop', '~> 1.6.0', require: false
gem 'bunny' # rabbit-mq
gem 'google-cloud-pubsub', '>= 1.9.3' # google pub/sub
gem 'ruby-kafka' # kafka pub/sub

group :test do
  gem 'database_cleaner-active_record'
  gem 'sqlite3', '~> 1.4'
end

# Specify your gem's dependencies in pub_sub_model_sync.gemspec
gemspec
