# frozen_string_literal: true

module StubListeners
  def stub_with_subscriber(action, mapping: [], settings: {}, &block)
    subscriber = PubSubModelSync::Subscriber.new('SubscriberUser', action, mapping: mapping, settings: settings)
    PubSubModelSync::Config.subscribers.push(subscriber)
    block.call(subscriber)
    PubSubModelSync::Config.subscribers.pop
  end
end

RSpec.configure do |config|
  config.include StubListeners
end
