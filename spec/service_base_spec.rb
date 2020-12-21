# frozen_string_literal: true

RSpec.describe PubSubModelSync::ServiceBase do
  let(:inst) { described_class.new }
  let(:payload) { PubSubModelSync::Payload.new({}, {}) }
  let(:config) { PubSubModelSync::Config }

  describe 'when processing message' do
    before { allow(config).to receive(:log) }
    it 'does not process if message is coming from same app' do
      msg = 'Skip message from same origin'
      payload.headers[:app_key] = 'test_app'
      allow(config).to receive(:subscription_key).and_return('test_app')
      expect(config).to receive(:log).with(include(msg), anything)
      inst.send(:process_message, payload.to_json)
    end

    it 'does process if message is coming from different app' do
      payload.headers[:app_key] = 'unknown_app'
      allow(config).to receive(:subscription_key).and_return('test_app')
      expect_any_instance_of(PubSubModelSync::MessageProcessor)
        .to receive(:process)
      inst.send(:process_message, payload.to_json)
    end
  end
end
