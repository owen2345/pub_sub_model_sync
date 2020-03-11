# frozen_string_literal: true

namespace :pub_sub_model_sync do
  desc 'Start listening syncs'
  task start: :environment do
    PubSubModelSync::Runner.new.run
  end
end
