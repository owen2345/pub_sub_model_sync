# frozen_string_literal: true

RSpec.describe PubSubModelSync::ServiceBase do
  let(:inst) { described_class.new }
  let(:payload_attrs) { { klass: 'Tester', action: :test } }
  let(:payload) { PubSubModelSync::Payload.new({}, payload_attrs, { app_key: 'unknown_app' }) }
  let(:config) { PubSubModelSync::Config }
  before do
    allow(Process).to receive(:exit!)
    allow(inst).to receive(:sleep)
  end

  describe 'when publishing message' do
    before { payload.headers[:forced_ordering_key] = 'mandatory_key' }

    it 'reduces payload size when not debug mode' do
      allow(inst.config).to receive(:debug).and_return(false)
      res = inst.send(:encode_payload, payload)
      expect(res).not_to include('forced_ordering_key')
    end

    it 'does not reduce payload size when debug mode' do
      allow(inst.config).to receive(:debug).and_return(true)
      res = inst.send(:encode_payload, payload)
      expect(res).to include('forced_ordering_key')
    end
  end

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

      describe 'when failed' do
        it 'retries for 5 times when any error' do
          stub_process_with(times: 100) { raise('any error') }
          expect(inst).to receive(:decode_payload).exactly(5 + 1).times
          inst.send(:process_message, payload.to_json)
        end

        it 'exits the system when problem persists' do
          stub_process_with(times: 100) { raise('any error') }
          expect(Process).to receive(:exit!)
          inst.send(:process_message, payload.to_json)
        end
      end
    end
  end

  private

  def stub_process_with(times: 1, &block)
    counter = 0
    allow(inst).to receive(:parse_payload).and_call_original
    allow_any_instance_of(PubSubModelSync::Payload).to receive(:process) do
      block.call if (counter += 1) <= times
    end
  end
end
