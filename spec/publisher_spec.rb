# frozen_string_literal: true

RSpec.describe PubSubModelSync::Publisher do
  let(:publisher_klass) { 'PublisherUser' }
  let(:inst) { described_class.new }
  let(:connector) { inst.connector }
  it '.publish_data' do
    data = { message: 'hello' }
    action = :greeting
    attributes = hash_including(action: action, klass: publisher_klass)
    expect(connector).to receive(:publish).with(data, attributes)
    inst.publish_data(publisher_klass, data, action)
  end

  describe '.publish_model' do
    let(:model) { PublisherUser2.new(name: 'name', email: 'email', age: 10) }
    let(:action) { :update }
    it 'filter to only accepted attributes' do
      expected_data = { name: model.name }
      expect(connector).to receive(:publish).with(expected_data, anything)
      inst.publish_model(model, action, { attrs: [:name] })
    end
    it 'custom class name' do
      custom_klass = 'User'
      attrs = hash_including(action: action, klass: custom_klass)
      expect(connector).to receive(:publish).with(anything, attrs)
      inst.publish_model(model, action)
    end
    it 'custom identifier' do
      custom_id_val = 10
      attrs = hash_including(id: custom_id_val)
      allow(model).to receive(:custom_id).and_return(custom_id_val)
      expect(connector).to receive(:publish).with(anything, attrs)
      inst.publish_model(model, action)
    end
    it 'empty data when action is destroy' do
      model = PublisherUser.new(name: 'name')
      expected_data = {}
      expect(connector).to receive(:publish).with(expected_data, anything)
      inst.publish_model(model, :destroy)
    end
    it 'aliased attributes' do
      expected_data = hash_including(full_name: model.name, email: model.email)
      expect(connector).to receive(:publish).with(expected_data, anything)
      inst.publish_model(model, action, attrs: %i[name:full_name email])
    end
  end
end
