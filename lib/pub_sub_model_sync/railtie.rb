# frozen_string_literal: true

require 'pub_sub_model_sync'
require 'rails'
require 'pub_sub_model_sync/config'
module PubSubModelSync
  class Railtie < ::Rails::Railtie
    railtie_name :pub_sub_model_sync

    rake_tasks do
      load 'pub_sub_model_sync/tasks/worker.rake'
    end

    configure do
      if PubSubModelSync::Config.enable_rails4_before_commit && defined?(ActiveRecord)
        require 'pub_sub_model_sync/initializers/before_commit'
      end
    end
  end
end
