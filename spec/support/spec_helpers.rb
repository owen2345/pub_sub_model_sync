# frozen_string_literal: true

module SpecHelpers
  def expect_publish_with_headers(data, times: 1)
    klass = PubSubModelSync::MessagePublisher
    allow(klass).to receive(:publish).and_call_original
    yield
    exp_params = have_attributes(headers: hash_including(data))
    expect(klass).to have_received(:publish).with(exp_params).exactly(times).times
  end

  def mock_publisher_callback(callback, model_attrs, method = :new, &block)
    klass = Class.new(PublisherUser)
    allow(klass).to receive(:name).and_return('PublisherUser')
    klass.send(callback, &block)
    klass.send(method, model_attrs)
  end

  def mock_ps_subscribe_custom(action, from_klass: 'SubscriberUser', id: :id, from_action: nil, &block)
    settings = { id: id, mode: :custom_model, from_klass: from_klass, from_action: from_action }
    subscriber = SubscriberUser.send(:add_ps_subscriber, action, nil, settings)
    block.call(SubscriberUser)
    PubSubModelSync::Config.subscribers = PubSubModelSync::Config.subscribers - [subscriber]
  end
end

RSpec.configure do |config|
  config.include SpecHelpers
end
