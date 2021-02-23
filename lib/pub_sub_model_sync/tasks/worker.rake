# frozen_string_literal: true

namespace :pub_sub_model_sync do
  desc 'Start listening syncs'
  task start: :environment do
    # https://github.com/zendesk/ruby-kafka#consumer-groups
    # Each consumer process will be assigned one or more partitions from each topic that the group
    #   subscribes to. In order to handle more messages, simply start more processes.
    if PubSubModelSync::Config.service_name == :kafka
      (PubSubModelSync::ServiceKafka::QTY_WORKERS - 1).times.each do
        Thread.new do
          Thread.current.abort_on_exception = true
          PubSubModelSync::Runner.new.run
        end
      end
    end
    PubSubModelSync::Runner.new.run
  end
end
