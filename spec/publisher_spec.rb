# frozen_string_literal: true

RSpec.describe PubSubModelSync::Publisher do
  let(:model) { PublisherUser2.new(id: 1, name: 'name', email: 'email', age: 10) }
  let(:klass_name) { model.class.name }
  let(:action) { :update }

  describe 'settings' do
    it 'includes action and klass' do
      inst = described_class.new([:name], klass_name, action)
      payload = inst.payload(model, action)
      expect(payload.attributes).to include({ klass: klass_name, action: action })
    end

    it 'includes custom key' do
      inst = described_class.new([:name], klass_name, action)
      payload = inst.payload(model, action)
      expect(payload.headers[:key]).to include("#{action}/#{model.id}")
    end

    it 'supports for custom class name' do
      as_klass = 'CustomClass'
      inst = described_class.new([:name], klass_name, action, as_klass: as_klass)
      payload = inst.payload(model, action)
      expect(payload.attributes).to match(hash_including(klass: as_klass))
    end
  end

  describe 'data' do
    it 'filters only accepted attributes' do
      attrs = [:name]
      inst = described_class.new(attrs, klass_name, action)
      expected_data = attrs.map { |attr| [attr, model.send(attr)] }.to_h
      payload = inst.payload(model, action)
      expect(payload.data).to eq expected_data
    end

    it 'supports for aliased attributes' do
      attrs = %i[name:full_name email]
      inst = described_class.new(attrs, klass_name, action)
      expected_data = { full_name: model.name, email: model.email }
      payload = inst.payload(model, action)
      expect(payload.data).to eq expected_data
    end

    it 'includes custom headers when provided' do
      custom_headers = { key: 'custom key' }
      inst = described_class.new([], klass_name, action)
      payload = inst.payload(model, action, custom_headers: custom_headers)
      expect(payload).to have_attributes(headers: include(custom_headers))
    end

    it 'uses custom_data as the payload data when defined' do
      custom_data = { id: 100 }
      inst = described_class.new([], klass_name, action)
      payload = inst.payload(model, action, custom_data: custom_data)
      expect(payload).to have_attributes(data: custom_data)
    end
  end
end
