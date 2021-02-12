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
    klass.send(callback, &block)
    klass.send(method, model_attrs)
  end
end

RSpec.configure do |config|
  config.include SpecHelpers
end
