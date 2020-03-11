# frozen_string_literal: true

require 'bundler/setup'
require 'pub_sub_model_sync'
require 'active_record'
require 'spec_init_model'

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
end
