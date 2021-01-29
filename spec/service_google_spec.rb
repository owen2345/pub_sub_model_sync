# frozen_string_literal: true

RSpec.describe PubSubModelSync::ServiceGoogle do
  let(:msg_attrs) { { 'service_model_sync' => true } }
  let(:payload_attrs) { { klass: 'Tester', action: :test } }
  let(:payload) { PubSubModelSync::Payload.new({}, payload_attrs) }
  let(:mock_message) do
    double('Message', data: payload.to_json, attributes: msg_attrs)
  end
  let(:mock_service_message) do
    double('ServiceMessage', message: mock_message, acknowledge!: true)
  end
  let(:mock_service_unknown_message) do
    mock_message.attributes['service_model_sync'] = nil
    mock_service_message
  end
  let(:inst) { described_class.new }
  before { allow(inst).to receive(:sleep) }

  describe 'initializer' do
    it 'connects to pub/sub service' do
      expect(inst.service).not_to be_nil
    end
    it 'connects to topic' do
      expect(inst.topic).not_to be_nil
    end

    it 'enables message ordering' do
      topic_klass = PubSubModelSync::MockGoogleService::MockTopic
      expect_any_instance_of(topic_klass).to receive(:enable_message_ordering!)
      described_class.new
    end
  end

  describe '.listen_messages' do
    it 'subscribes to topic' do
      expect(inst.topic).to receive(:subscription)
      inst.listen_messages
    end
    it 'listens for new messages' do
      expect(inst.topic.subscription).to receive(:listen).and_call_original
      inst.listen_messages
    end
    it 'starts subscriber' do
      subscriber = inst.topic.subscription.listen
      expect(subscriber).to receive(:start)
      inst.listen_messages
    end
    it 'awaits for messages' do
      expect(inst).to receive(:sleep)
      inst.listen_messages
    end
  end

  describe '.process_message' do
    let(:message_processor) { PubSubModelSync::MessageProcessor }
    before { allow(inst).to receive(:log) }
    it 'ignores if not a pub/sub model sync message (unknown)' do
      expect(message_processor).not_to receive(:new)
      inst.send(:process_message, mock_service_unknown_message)
    end
    it 'sends payload to message processor' do
      expect(message_processor).to receive(:new).and_call_original
      inst.send(:process_message, mock_service_message)
    end
    it 'prints error processing when failed' do
      error_msg = 'Invalid params'
      allow(message_processor).to receive(:new).and_raise(error_msg)
      expect(inst).to receive(:log).with(include(error_msg), :error)
      inst.send(:process_message, mock_service_message)
    end

    describe 'mark as received message' do
      it 'marks message as received when success' do
        expect(mock_service_message).to receive(:acknowledge!)
        inst.send(:process_message, mock_service_message)
      end
      it 'marks message as received even if failed' do
        expect(mock_service_message).to receive(:acknowledge!)
        allow(mock_message).to receive(:data).and_return('invalid_data')
        allow(inst).to receive(:log)
        inst.send(:process_message, mock_service_message)
      end
      it 'marks message as received even if unknown message' do
        expect(mock_service_unknown_message).to receive(:acknowledge!)
        inst.send(:process_message, mock_service_unknown_message)
      end
    end
  end

  describe '.publish' do
    it 'delivery message' do
      expect(inst.topic).to receive(:publish_async).with(payload.to_json, anything)
      inst.publish(payload)
    end

    it 'publishes ordered messages' do
      expected_hash = hash_including(ordering_key: anything)
      expect(inst.topic).to receive(:publish_async).with(anything, expected_hash)
      inst.publish(payload)
    end
  end

  describe '.stop' do
    before { inst.listen_messages }
    it 'stop current subscription' do
      expect(inst.subscriber).to receive(:stop!)
      inst.stop
    end
  end
end
