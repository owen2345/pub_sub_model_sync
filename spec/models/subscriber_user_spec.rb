# frozen_string_literal: true

RSpec.describe SubscriberUser do
  let(:model) { described_class.create(name: 'old name') }
  let(:message_processor) { PubSubModelSync::MessageProcessor }
  let(:data) { { name: 'Name', email: 'sample email', age: 10, id: model.id } }

  it 'syncs only defined attributes when notification is processed' do
    action = :update
    add_subscription(action, mapping = %i[name email]) do
      stub_subscriber(:find_model, model)
      send_notification(action, data)
      expect(model.reload.name).to eq(data[:name])
      expect(model.email).to eq(data[:email])
      expect(model.age).not_to eq(data[:age])
    end
  end

  private

  def stub_subscriber(method_name, result)
    allow_any_instance_of(PubSubModelSync::SubscriberProcessor).to receive(method_name).and_return(result)
  end

  def send_notification(action, data)
    payload = PubSubModelSync::Payload.new(data, { klass: 'SubscriberUser', action: action })
    message_processor.new(payload).process!
  end
end
