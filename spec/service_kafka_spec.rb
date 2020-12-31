# frozen_string_literal: true

RSpec.describe PubSubModelSync::ServiceKafka do
  let(:payload) { PubSubModelSync::Payload.new({}, {}) }
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
  before { allow(config).to receive(:kafka_connection).and_return([[8080], { log: nil }]) }

  describe 'initializer' do
    it 'connects to pub/sub service' do
      expect(service).not_to be_nil
    end
  end

  describe '.listen_messages' do
    let(:consumer) { PubSubModelSync::MockKafkaService::MockConsumer.new }
    before { allow(service).to receive(:consumer).and_return(consumer) }
    after { inst.listen_messages }
    it 'starts consumer' do
      expect(consumer).to receive(:subscribe)
    end
    it 'listens for messages' do
      expect(consumer).to receive(:each_message)
    end
  end

  describe '.process_message' do
    let(:message_processor) { PubSubModelSync::MessageProcessor }
    before { allow(inst).to receive(:log) }
    it 'ignores unknown message' do
      expect(message_processor).not_to receive(:new)
      inst.send(:process_message, invalid_message)
    end
    it 'sends payload to message processor' do
      expect(message_processor)
        .to receive(:new).with(be_kind_of(payload.class)).and_call_original
      inst.send(:process_message, message)
    end
    it 'prints error message when failed processing' do
      error_msg = 'Invalid params'
      allow(message_processor).to receive(:new).and_raise(error_msg)
      expect(inst).to receive(:log).with(include(error_msg), :error)
      inst.send(:process_message, message)
    end
  end

  describe '.publish' do
    it 'formats message' do
      settings = hash_including(:topic, :headers)
      data_regex = /"data":{(.*)"attributes":{/
      expect(producer).to receive(:produce).with(match(data_regex), settings)
      inst.publish(payload)
    end
    it 'delivers the message' do
      expect(producer).to receive(:deliver_messages)
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
