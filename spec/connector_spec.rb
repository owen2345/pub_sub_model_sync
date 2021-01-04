# frozen_string_literal: true

RSpec.describe PubSubModelSync::Connector do
  let(:inst) { described_class.new }
  let(:config) { PubSubModelSync::Config }
  describe 'Google service' do
    before { allow(config).to receive(:service_name).and_return(:google) }
    it 'initializes google service' do
      expect(inst.service).to be_a(PubSubModelSync::ServiceGoogle)
    end

    %i[listen_messages publish stop].each do |action|
      it "delegates .#{action} to service" do
        expect(inst.service).to receive(action)
        inst.send(action, {}, {})
      end
    end
  end

  describe 'Rabbitmp' do
    before { allow(config).to receive(:service_name).and_return(:rabbit_mp) }
    it 'initializes rabbitMQ service' do
      expect(inst.service).to be_a(PubSubModelSync::ServiceRabbit)
    end

    %i[listen_messages publish stop].each do |action|
      it "delegates .#{action} to service" do
        expect(inst.service).to receive(action)
        inst.send(action, {}, {})
      end
    end
  end

  describe 'Kafka' do
    before do
      allow(config).to receive(:service_name).and_return(:kafka)
      allow(config).to receive(:kafka_connection).and_return([[8080], { log: nil }])
    end
    it 'initializes Kafka service' do
      expect(inst.service).to be_a(PubSubModelSync::ServiceKafka)
    end

    %i[listen_messages publish stop].each do |action|
      it "delegates .#{action} to service" do
        expect(inst.service).to receive(action)
        inst.send(action, {}, {})
      end
    end
  end
end
