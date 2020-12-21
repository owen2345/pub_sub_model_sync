# frozen_string_literal: true

require 'bundler/setup'
require 'pub_sub_model_sync'
require 'active_record'
require 'spec_init_model'
require 'pub_sub_model_sync/mock_google_service'
require 'pub_sub_model_sync/mock_rabbit_service'
require 'pub_sub_model_sync/mock_kafka_service'
require 'database_cleaner/active_record'

root_path = File.dirname __dir__
Dir[File.join(root_path, 'spec', 'support', '**', '*.rb')].each do |f|
  require f
end

# raise sync errors during tests
PubSubModelSync::Config.logger = :raise_error
PubSubModelSync::Config.debug = true

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before(:each) do
    klass = PubSubModelSync::ServiceBase
    allow_any_instance_of(klass).to receive(:same_app_message?).and_return(false)
  end

  # mock google service
  config.before(:each) do
    pub_sub_mock = PubSubModelSync::MockGoogleService.new
    allow(Google::Cloud::Pubsub).to receive(:new).and_return(pub_sub_mock)
  end

  # mock rabbit service
  config.before(:each) do
    bunny_mock = PubSubModelSync::MockRabbitService.new
    allow(Bunny).to receive(:new).and_return(bunny_mock)
  end

  # mock kafka service
  config.before(:each) do
    kafka_mock = PubSubModelSync::MockKafkaService.new
    allow(Kafka).to receive(:new).and_return(kafka_mock)
  end
end

# database cleaner
RSpec.configure do |config|

  config.before(:suite) do
    DatabaseCleaner.strategy = :deletion
    DatabaseCleaner.clean_with(:truncation)
  end

  config.around(:each) do |example|
    DatabaseCleaner.cleaning do
      example.run
    end
  end
end
