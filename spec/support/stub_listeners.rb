# frozen_string_literal: true

module StubListeners
  def stub_subscriber(subscriber, &block)
    PubSubModelSync::Config.subscribers.push(subscriber)
    block.call
    PubSubModelSync::Config.subscribers.pop
  end
end

RSpec.configure do |config|
  config.include StubListeners
end
