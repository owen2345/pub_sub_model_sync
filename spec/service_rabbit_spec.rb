# frozen_string_literal: true

RSpec.describe PubSubModelSync::ServiceRabbit do
  let(:meta_info) { { type: 'service_model_sync' } }
  let(:invalid_meta_info) { { type: 'unknown' } }
  let(:delivery_info) { {} }
  let(:payload) { PubSubModelSync::Payload.new({}, {}) }
  let(:inst) { described_class.new }
  let(:service) { inst.service }
  let(:channel) { service.channel }

  before { allow(inst).to receive(:loop) }

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
    it 'subscribes to queue' do
      expect(channel).to receive(:queue).and_call_original
    end
    it 'subscribes to topic' do
      expect(channel).to receive(:topic).and_call_original
    end
    it 'listens for messages' do
      expect(channel.queue).to receive(:subscribe)
    end
  end

  describe '.process_message' do
    let(:message_processor) { PubSubModelSync::MessageProcessor }
    it 'ignores unknown message' do
      expect(message_processor).not_to receive(:new)
      args = [delivery_info, invalid_meta_info, payload.to_json]
      inst.send(:process_message, *args)
    end
    it 'sends payload to message processor' do
      expect(message_processor)
        .to receive(:new).with(be_kind_of(payload.class)).and_call_original
      args = [delivery_info, meta_info, payload.to_json]
      inst.send(:process_message, *args)
    end
    it 'prints error message when failed processing' do
      error_msg = 'Invalid params'
      allow(message_processor).to receive(:new).and_raise(error_msg)
      expect(inst).to receive(:log).with(include(error_msg), :error)

      args = [delivery_info, meta_info, payload.to_json]
      inst.send(:process_message, *args)
    end
  end

  describe '.publish' do
    it 'deliveries message' do
      expected_args = [payload.to_json, hash_including(:routing_key, :type)]
      expect(channel.topic).to receive(:publish).with(*expected_args)
      inst.publish(payload)
    end
    it 'retries 2 times when TimeoutError' do
      error = 'retrying....'
      allow(inst).to receive(:deliver_data).and_raise(Timeout::Error)
      allow(inst).to receive(:log)
      expect(inst).to receive(:log).with(include(error), :error).twice
      inst.publish(payload) rescue nil
    end
  end

  describe '.stop' do
    it 'stops current subscription' do
      expect(service).to receive(:close)
      inst.stop
    end
  end
end
