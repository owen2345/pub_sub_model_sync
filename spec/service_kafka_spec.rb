# frozen_string_literal: true

RSpec.describe PubSubModelSync::ServiceKafka do
  let(:payload_attrs) { { klass: 'Tester', action: :test } }
  let(:payload) { PubSubModelSync::Payload.new({}, payload_attrs) }
  let(:message) do
    OpenStruct.new(value: payload.to_json,
                   headers: { 'service_model_sync' => true })
  end
  let(:invalid_message) do
    OpenStruct.new(headers: { 'invalid_partition' => true })
  end
  let(:inst) { described_class.new }
  let(:service) { inst.service }
  let(:producer) { inst.send(:producer) }
  let(:config) { PubSubModelSync::Config }
  let(:consumer) { PubSubModelSync::MockKafkaService::MockConsumer.new }
  before do
    allow(config).to receive(:kafka_connection).and_return([[8080], { log: nil }])
    allow(Process).to receive(:exit!)
  end

  describe 'initializer' do
    it 'connects to pub/sub service' do
      expect(service).not_to be_nil
    end
  end

  describe '.listen_messages' do
    before { allow(service).to receive(:consumer).and_return(consumer) }
    after { inst.listen_messages }
    it 'starts consumer' do
      expect(consumer).to receive(:subscribe)
    end
    it 'listens for messages' do
      expect(consumer).to receive(:each_message)
    end

    it 'subscribes to multiple topics if provided' do
      names = ['topic 1', 'topic2']
      allow(inst).to receive(:topic_names).and_return(names)
      allow(consumer).to receive(:subscribe)
      names.each do |name|
        expect(consumer).to receive(:subscribe).with(name)
      end
    end
  end

  describe '.process_message' do
    let(:message_processor) { PubSubModelSync::MessageProcessor }
    before do
      allow(inst).to receive(:log)
      allow(inst).to receive(:consumer).and_return(consumer)
    end

    it 'ignores unknown message' do
      expect(message_processor).not_to receive(:new)
      inst.send(:process_message, invalid_message)
    end

    describe 'when processing a valid message' do
      it 'sends payload to message processor' do
        expect(message_processor)
          .to receive(:new).with(be_kind_of(payload.class)).and_call_original
        inst.send(:process_message, message)
      end

      it 'acks the message to mark as processed' do
        expect(inst.consumer).to receive(:mark_message_as_processed).with(message)
        inst.send(:process_message, message)
      end
    end

    describe 'when failed processing a valid message' do
      let(:error_msg) { 'error message' }
      before { allow(message_processor).to receive(:new).and_raise(error_msg) }

      it 'raises the error' do
        expect { inst.send(:process_message, message) }.to raise_error(error_msg)
      end

      it 'does not ack the message to be retried by pubsub' do
        expect(inst.consumer).not_to receive(:mark_message_as_processed)
        inst.send(:process_message, message) rescue nil # rubocop:disable Style/RescueModifier
      end
    end
  end

  describe '.publish' do
    it 'formats message' do
      info = hash_including(:topic, :headers)
      data_regex = /"data":{(.*)"info":{/
      expect(producer).to receive(:produce).with(match(data_regex), info)
      inst.publish(payload)
    end

    it 'delivers the message' do
      expect(producer).to receive(:produce).with(payload.to_json, anything)
      inst.publish(payload)
    end

    it 'uses defined :ordering_key as the partition_key' do
      order_key = 'custom_order_key'
      payload.headers[:ordering_key] = order_key
      expect(producer).to receive(:produce).with(anything, hash_including(partition_key: order_key))
      inst.publish(payload)
    end

    it 'uses defined :topic_name as the topic' do
      topic_name = 'custom_topic_name'
      payload.headers[:topic_name] = topic_name
      expect(producer).to receive(:produce).with(anything, hash_including(topic: topic_name))
      inst.publish(payload)
    end

    it 'creates custom topic if not exist' do
      topic_name = 'custom_topic_name'
      payload.headers[:topic_name] = topic_name
      expect(service).to receive(:create_topic).with(topic_name)
      inst.publish(payload)
    end

    it 'publishes to all topics when defined' do
      topic_names = %w[topic1 topic2]
      payload.headers[:topic_name] = topic_names
      topic_names.each do |topic_name|
        expect(service).to receive(:create_topic).with(topic_name)
      end
      inst.publish(payload)
    end
  end

  describe '.stop' do
    it 'stops current subscription' do
      inst.send(:start_consumer)
      expect(inst.consumer).to receive(:stop)
      inst.stop
    end

    # xit 'stop producer at exit' do
    #   pending 'TODO: make a test with exit 0 and listen for producer.shutdown'
    # end
  end
end
