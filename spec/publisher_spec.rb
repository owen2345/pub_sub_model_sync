# frozen_string_literal: true

RSpec.describe PubSubModelSync::Publisher do
  let(:model) { PublisherUser2.new(name: 'name', email: 'email', age: 10) }
  let(:klass_name) { model.class.name }
  let(:action) { :update }

  describe 'settings' do
    it 'includes action and klass' do
      inst = described_class.new([:name], klass_name, action)
      payload = inst.payload(model, action)
      expect(payload[:attrs]).to eq({ klass: klass_name, action: action })
    end

    it 'custom class name' do
      as_klass = 'CustomClass'
      inst = described_class.new([:name], klass_name, action, as_klass)
      payload = inst.payload(model, action)
      expect(payload[:attrs]).to match(hash_including(klass: as_klass))
    end
  end

  describe 'data' do
    it 'filter to only accepted attributes' do
      inst = described_class.new([:name], klass_name, action)
      expected_data = { name: model.name }
      payload = inst.payload(model, action)
      expect(payload[:data]).to eq expected_data
    end

    it 'aliased attributes' do
      attrs = %i[name:full_name email]
      inst = described_class.new(attrs, klass_name, action)
      expected_data = { full_name: model.name, email: model.email }
      payload = inst.payload(model, action)
      expect(payload[:data]).to eq expected_data
    end
  end
end
