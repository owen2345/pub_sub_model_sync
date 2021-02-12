# frozen_string_literal: true

RSpec.describe PubSubModelSync::ServiceBase do
  let(:inst) { described_class.new }
  let(:payload_attrs) { { klass: 'Tester', action: :test } }
  let(:payload) { PubSubModelSync::Payload.new({}, payload_attrs) }
  let(:config) { PubSubModelSync::Config }

  describe 'when processing message' do
    before { allow(config).to receive(:log) }
    describe 'when checking message source' do
      before do
        allow_any_instance_of(described_class).to receive(:same_app_message?).and_call_original
      end
      it 'does not process if message is coming from same app' do
        msg = 'Skipping message from same origin'
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
end
