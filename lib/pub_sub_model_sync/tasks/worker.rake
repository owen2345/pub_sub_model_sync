# frozen_string_literal: true

namespace :pub_sub_model_sync do
  desc 'Start listening syncs'
  task start: :environment do
    if PubSubModelSync::Config.service_name != :kafka
      PubSubModelSync::Runner.new.run
    else
      # https://github.com/zendesk/ruby-kafka#consumer-groups
      # Each consumer process will be assigned one or more partitions from each topic that the group
      #   subscribes to. In order to handle more messages, simply start more processes.
      PubSubModelSync::ServiceKafka::QTY_WORKERS.times.each do
        Thread.new do
          Thread.current.abort_on_exception = true
          PubSubModelSync::Runner.new.run
        end
      end
    end
  end
end
