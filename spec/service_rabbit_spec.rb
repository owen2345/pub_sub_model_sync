# frozen_string_literal: true

RSpec.describe PubSubModelSync::ServiceRabbit do
  let(:meta_info) { { type: 'service_model_sync' } }
  let(:invalid_meta_info) { { type: 'unknown' } }
  let(:delivery_info) { double(delivery_tag: true) }
  let(:payload_attrs) { { klass: 'Tester', action: :test } }
  let(:payload) { PubSubModelSync::Payload.new({}, payload_attrs) }
  let(:inst) { described_class.new }
  let(:service) { inst.service }
  let(:channel) { service.channel }
  let(:queue_klass) { PubSubModelSync::MockRabbitService::MockQueue }
  let(:queue) { instance_double(queue_klass, channel: channel) }
  let(:channel_klass) { PubSubModelSync::MockRabbitService::MockChannel }

  before do
    allow(inst).to receive(:loop)
    allow(Process).to receive(:exit!)
  end

  describe 'initializer' do
    it 'connects to pub/sub service' do
      expect(service).not_to be_nil
    end
  end

  describe '.listen_messages' do
    after { inst.listen_messages }
    it 'starts service' do
      expect(service).to receive(:start)
    end
    it 'creates channel' do
      expect(service).to receive(:create_channel).and_call_original
    end

    it 'subscribe to queue' do
      expect(channel).to receive(:fanout).and_call_original
    end

    it 'subscribes to topic' do
      expect(channel).to receive(:fanout).and_call_original
    end
    it 'listens for messages' do
      expect(channel.queue).to receive(:subscribe)
    end

    it 'connects to multiple topics if provided' do
      names = ['topic 1', 'topic 2']
      allow(inst).to receive(:topic_names).and_return(names)
      names.each do |name|
        expect_any_instance_of(channel_klass).to receive(:fanout).with(name)
      end
    end
  end

  describe '.process_message' do
    let(:message_processor) { PubSubModelSync::MessageProcessor }
    before { allow(inst).to receive(:log) }

    it 'ignores unknown message' do
      expect(message_processor).not_to receive(:new)
      args = [queue, delivery_info, invalid_meta_info, payload.to_json]
      inst.send(:process_message, *args)
    end

    describe 'when received a valid message' do
      let(:args) { [queue, delivery_info, meta_info, payload.to_json] }

      it 'sends payload to message processor' do
        expect(message_processor)
          .to receive(:new).with(be_kind_of(payload.class)).and_call_original
        inst.send(:process_message, *args)
      end

      it 'acks the message once processed the message to mark as processed' do
        expect(channel).to receive(:ack)
        inst.send(:process_message, *args)
      end
    end

    describe 'when failed' do
      let(:args) { [queue, delivery_info, meta_info, payload.to_json] }
      let(:error_msg) { 'Error syncing data' }
      before { allow(message_processor).to receive(:new).and_raise(error_msg) }

      it 'raises the error' do
        expect { inst.send(:process_message, *args) }.to raise_error(error_msg)
      end

      it 'does not ack the message to auto retry by pubsub' do
        expect(channel).not_to receive(:ack)
        inst.send(:process_message, *args) rescue nil # rubocop:disable Style/RescueModifier
      end
    end
  end

  describe '.publish' do
    it 'deliveries message' do
      expected_args = [payload.to_json, hash_including(:routing_key, :type)]
      expect_publish_with(*expected_args)
      inst.publish(payload)
    end

    it 'retries 2 times when TimeoutError' do
      error = 'retrying....'
      allow(inst).to receive(:deliver_data).and_raise(Timeout::Error)
      allow(inst).to receive(:log)
      expect(inst).to receive(:log).with(include(error), :error).twice
      inst.publish(payload) rescue nil # rubocop:disable Style/RescueModifier
    end

    it 'uses custom exchange when defined :topic_name' do
      topic_name = 'custom_topic_name'
      payload.headers[:topic_name] = topic_name
      expect(channel).to receive(:fanout).with(topic_name).and_call_original
      inst.publish(payload)
    end

    it 'publishes to all topics when defined' do
      topic_names = %w[topic1 topic2]
      payload.headers[:topic_name] = topic_names
      topic_names.each do |topic_name|
        expect(channel).to receive(:fanout).with(topic_name).and_call_original
      end
      inst.publish(payload)
    end

    it 'uses :ordering_key as the :routing_key when defined' do
      order_key = 'custom_order_key'
      payload.headers[:ordering_key] = order_key
      expect_publish_with(anything, hash_including(routing_key: order_key))
      inst.publish(payload)
    end
  end

  describe '.stop' do
    it 'stops current subscription' do
      expect(service).to receive(:close)
      inst.stop
    end
  end

  private

  def expect_publish_with(*args)
    expect_any_instance_of(queue_klass).to receive(:publish).with(*args)
  end
end
