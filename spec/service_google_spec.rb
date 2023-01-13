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
  let(:topic) { inst.topics.values.first }
  before do
    allow(inst).to receive(:sleep)
    allow(Process).to receive(:exit!)
  end

  describe 'initializer' do
    it 'connects to pub/sub service' do
      expect(inst.service).not_to be_nil
    end

    it 'connects to topic' do
      expect(topic).not_to be_nil
    end

    it 'connects to multiple topics if provided' do
      names = ['topic 1', 'topic2']
      allow(described_class.config).to receive(:topic_name).and_return(names)
      inst = described_class.new
      expect(inst.topics.values.count).to eq names.count
    end

    it 'enables message ordering' do
      topic_klass = PubSubModelSync::MockGoogleService::MockTopic
      expect_any_instance_of(topic_klass).to receive(:enable_message_ordering!)
      described_class.new
    end
  end

  describe '.listen_messages' do
    it 'subscribes to topic' do
      expect(topic).to receive(:subscription)
      inst.listen_messages
    end

    it 'listens for new messages' do
      expect(topic.subscription).to receive(:listen).and_call_original
      inst.listen_messages
    end

    it 'starts subscriber' do
      subscriber = topic.subscription.listen
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

    describe 'when received a valid message' do
      it 'sends payload to message processor' do
        expect(message_processor).to receive(:new).and_call_original
        inst.send(:process_message, mock_service_message)
      end

      it 'acknowledges the message to mark as processed' do
        expect(mock_service_message).to receive(:acknowledge!)
        inst.send(:process_message, mock_service_message)
      end
    end

    describe 'when failed processing a message' do
      let(:error_msg) { 'Invalid params' }
      before { allow(message_processor).to receive(:new).and_raise(error_msg) }

      it 'raises the error' do
        expect { inst.send(:process_message, mock_service_message) }.to raise_error(error_msg)
      end

      it 'does not acknowledge the message to auto retry by pubsub' do
        expect(mock_service_message).not_to receive(:acknowledge!)
        inst.send(:process_message, mock_service_message) rescue nil # rubocop:disable Style/RescueModifier
      end
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
    it 'deliveries message' do
      expect(topic).to receive(:publish).with(payload.to_json, anything)
      inst.publish(payload)
    end

    it 'uses defined ordering_key as the :ordering_key' do
      expected_hash = hash_including(ordering_key: payload.headers[:ordering_key])
      expect(topic).to receive(:publish).with(anything, expected_hash)
      inst.publish(payload)
    end

    describe 'when enabled async mode' do
      before { allow(inst.config).to receive(:async).and_return(true) }

      it 'uses defined ordering_key as the :ordering_key' do
        expect(topic).to receive(:publish_async).with(payload.to_json, hash_including(:ordering_key))
        inst.publish(payload)
      end
    end

    it 'uses custom topic if defined' do
      topic_name = 'custom_topic_name'
      payload.headers[:topic_name] = topic_name
      expect(inst.service).to receive(:topic).with(topic_name)
      inst.publish(payload)
    end

    it 'publishes to all topics when defined' do
      topic_names = %w[topic1 topic2]
      payload.headers[:topic_name] = topic_names
      topic_names.each do |topic_name|
        expect(inst.service).to receive(:topic).with(topic_name)
      end
      inst.publish(payload)
    end

    # https://github.com/googleapis/google-cloud-ruby/blob/main/google-cloud-pubsub/OVERVIEW.md#handling-errors-with-ordered-keys
    describe 'when failed because of OrderingKeyError (Ordered messages that fail to publish to the Pub/Sub API due
              to error will put the ordering_key in a failed state)' do
      before do
        error = Google::Cloud::PubSub::OrderingKeyError.new('some error')
        calls = 0
        allow(topic).to receive(:publish) do
          (calls += 1) == 1 ? raise(error) : true
        end
      end

      it 'calls #resume_publish on topic to re-enable publish for the ordering_key' do
        expect(topic).to receive(:resume_publish).with(payload.headers[:ordering_key])
        inst.publish(payload)
      end

      it 'retries 1 time' do
        expect(topic).to receive(:publish).exactly(2)
        inst.publish(payload)
      end
    end
  end

  describe '.stop' do
    before { inst.listen_messages }
    it 'stops all subscribers' do
      expect(inst.subscribers.first).to receive(:stop!)
      inst.stop
    end
  end
end
