# frozen_string_literal: true

RSpec.describe PubSubModelSync::ServiceKafka do
  let(:msg_attrs) { { klass: 'User', action: 'action' } }
  let(:message_data) { { data: { msg: 'Hello' }, attributes: msg_attrs } }
  let(:message) do
    OpenStruct.new(value: message_data.to_json, partition: 'service_model_sync')
  end
  let(:invalid_message) { OpenStruct.new(partition: 'invalid_partition') }
  let(:inst) { described_class.new }
  let(:service) { inst.service }
  let(:producer) { inst.send(:producer) }

  describe 'initializer' do
    it 'connect to pub/sub service' do
      expect(service).not_to be_nil
    end
  end

  describe '.listen_messages' do
    let(:consumer) { PubSubModelSync::MockKafkaService::MockConsumer.new }
    before { allow(service).to receive(:consumer).and_return(consumer) }
    after { inst.listen_messages }
    it 'start consumer' do
      expect(consumer).to receive(:subscribe)
    end
    it 'listening messages' do
      expect(consumer).to receive(:each_message)
    end
  end

  describe '.process_message' do
    let(:message_processor) { PubSubModelSync::MessageProcessor }
    it 'ignore unknown message' do
      expect(message_processor).not_to receive(:new)
      inst.send(:process_message, invalid_message)
    end
    it 'process message' do
      expect(message_processor)
        .to receive(:new).with(message_data[:data], any_args).and_call_original
      inst.send(:process_message, message)
    end
    it 'error processing' do
      error_msg = 'Invalid params'
      allow(message_processor).to receive(:new).and_raise(error_msg)
      expect(inst).to receive(:log).with(include(error_msg), :error)
      inst.send(:process_message, message)
    end
  end

  describe '.publish' do
    it 'produce' do
      settings = hash_including(:topic, :partition_key)
      data_regex = /"data":{(.*)"attributes":{/
      expect(producer).to receive(:produce).with(match(data_regex), settings)
      inst.publish(message_data[:data], msg_attrs)
    end
    it 'deliver messages' do
      expect(producer).to receive(:deliver_messages)
      inst.publish(message_data[:data], msg_attrs)
    end
  end

  describe '.stop' do
    it 'stop current subscription' do
      inst.send(:start_consumer)
      expect(inst.consumer).to receive(:stop)
      inst.stop
    end

    xit 'stop producer at exit' do
      pending 'TODO: make a test with exit 0 and listen for producer.shutdown'
    end
  end
end
