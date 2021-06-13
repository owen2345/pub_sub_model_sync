# frozen_string_literal: true

RSpec.describe SubscriberUser do
  let(:model) { described_class.create(name: 'old name') }
  let(:message_processor) { PubSubModelSync::MessageProcessor }
  let(:data) { { name: 'Name', email: 'sample email', age: 10, id: model.id } }
  let(:action) { :sample_instance_notif }
  after { unsubscribe(action) }

  describe 'when instance subscriptions' do
    it 'fills model attributes with received data' do
      SubscriberUser.ps_subscribe(action, %w[id name]) {}
      expect_any_instance_of(SubscriberUser).to receive(:name=).with(data[:name])
      send_notification(action, data)
    end

    it 'calls provided block when processing subscription' do
      mock = ->(_data) {}
      SubscriberUser.ps_subscribe(action, %i[id name]) { |data| mock.call(data) }
      expect(mock).to receive(:call).with(data)
      send_notification(action, data)
    end

    it 'calls provided to_action when processing subscription' do
      SubscriberUser.ps_subscribe(action, %i[id name], to_action: :my_method)
      expect_any_instance_of(SubscriberUser).to receive(:my_method).with(data)
      send_notification(action, data)
    end
  end

  describe 'when class subscriptions' do
    it 'calls provided block when processing subscription' do
      mock = ->(_data) {}
      SubscriberUser.ps_class_subscribe(action) { |data| mock.call(data) }
      expect(mock).to receive(:call).with(data)
      send_notification(action, data, mode: :klass)
    end

    it 'calls provided to_action when processing subscription' do
      SubscriberUser.ps_class_subscribe(action, to_action: :my_method)
      expect(SubscriberUser).to receive(:my_method).with(data)
      send_notification(action, data, mode: :klass)
    end
  end

  private

  def unsubscribe(action)
    PubSubModelSync::Config.subscribers = PubSubModelSync::Config.subscribers.reject do |s|
      s.action == action
    end
  end

  def send_notification(action, data, mode: :model)
    payload = PubSubModelSync::Payload.new(data, { klass: 'SubscriberUser', action: action, mode: mode })
    message_processor.new(payload).process!
  end
end
