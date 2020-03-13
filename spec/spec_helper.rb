# frozen_string_literal: true

require 'bundler/setup'
require 'pub_sub_model_sync'
require 'active_record'
require 'spec_init_model'
require 'pub_sub_model_sync/mock_google_service'
require 'pub_sub_model_sync/mock_rabbit_service'

root_path = File.dirname __dir__
Dir[File.join(root_path, 'spec', 'support', '**', '*.rb')].each do |f|
  require f
end

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
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
end
