# frozen_string_literal: true

RSpec.describe PubSubModelSync::Publisher do
  let(:publisher_klass) { 'PublisherUser' }
  let(:inst) { described_class.new }
  let(:topic) { inst.connector.topic }
  it '.publish_data' do
    data = { message: 'hello' }
    action = :greeting
    attributes = hash_including(action: action, class: publisher_klass)
    expect(topic).to receive(:publish).with(data.to_json, attributes)
    inst.publish_data(publisher_klass, data, action)
  end

  describe '.publish_model' do
    let(:model) { PublisherUser2.new(name: 'name', email: 'email', age: 10) }
    let(:action) { :create }
    it 'filter to only accepted attributes' do
      expected_data = { name: model.name }
      expect(topic).to receive(:publish).with(expected_data.to_json, anything)
      inst.publish_model(model, action, { attrs: [:name] })
    end
    it 'custom class name' do
      custom_klass = 'User'
      attrs = hash_including(action: action, class: custom_klass)
      expect(topic).to receive(:publish).with(anything, attrs)
      inst.publish_model(model, action)
    end
    it 'custom identifier' do
      custom_id_val = 10
      attrs = hash_including(id: custom_id_val)
      allow(model).to receive(:custom_id).and_return(custom_id_val)
      expect(topic).to receive(:publish).with(anything, attrs)
      inst.publish_model(model, action)
    end
    it 'empty data when action is destroy' do
      expected_data = {}
      expect(topic).to receive(:publish).with(expected_data.to_json, anything)
      inst.publish_model(model, 'destroy')
    end
  end
end
