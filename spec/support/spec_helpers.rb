# frozen_string_literal: true

module SpecHelpers
  def expect_publish_with_headers(data, times: 1)
    klass = PubSubModelSync::MessagePublisher
    allow(klass.connector).to receive(:publish).and_call_original
    yield
    exp_params = have_attributes(headers: hash_including(data))
    expect(klass.connector).to have_received(:publish).with(exp_params).exactly(times).times
  end

  def mock_publisher_callback(callback, model_attrs, method = :new, &block)
    klass = Class.new(PublisherUser)
    allow(klass).to receive(:name).and_return('PublisherUser')
    klass.send(*Array(callback), &block)
    klass.send(method, model_attrs)
  end

  def add_subscription(action, mapping = [], settings = {}, &block)
    subscriber = SubscriberUser.send(:add_ps_subscriber, action, mapping, { mode: :model }.merge(settings))
    block.call(subscriber)
    PubSubModelSync::Config.subscribers = PubSubModelSync::Config.subscribers - [subscriber]
  end
end

RSpec.configure do |config|
  config.include SpecHelpers
end
