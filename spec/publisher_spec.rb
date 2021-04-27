# frozen_string_literal: true

RSpec.describe PubSubModelSync::Publisher do
  let(:model) { PublisherUser.new(id: 1, name: 'name', email: 'email', age: 10) }
  let(:action) { :update }
  let(:klass_name) { model.class.name }

  describe 'when building payload info' do
    it 'settings: includes action and klass' do
      payload = payload_for(action)
      expect(payload.settings).to include({ klass: klass_name, action: action })
    end

    it 'supports for custom class name' do
      as_klass = 'CustomClass'
      payload = payload_for(action, as_klass: as_klass)
      expect(payload.settings).to include({ klass: as_klass, action: action })
    end
  end

  describe 'when building headers' do
    let(:header_info) { { ordering_key: 'custom_key' } }

    it 'calls model method when provided Symbol value' do
      allow(model).to receive(:build_headers) { header_info }
      expect(model).to receive(:build_headers).with(action)
      payload = payload_for(action, headers: :build_headers)
      expect(payload.headers).to include(header_info)
    end

    it 'calls block when provided block value' do
      block = lambda { |_model, _action| {} }
      expect(block).to receive(:call).with(model, action).and_return(header_info)
      payload = payload_for(action, headers: block)
      expect(payload.headers).to include(header_info)
    end

    it 'uses provided data when passed a Hash' do
      data = header_info
      payload = payload_for(action, headers: data)
      expect(payload.headers).to include(data)
    end
  end

  describe 'when building data' do
    describe 'when parsing mapping' do
      it 'filters only defined attributes' do
        payload = payload_for(action, mapping: %w[id name])
        expect(payload.data).to eq({ id: model.id, name: model.name })
      end

      it 'supports for aliased attributes' do
        payload = payload_for(action, mapping: %w[id:uuid name:full_name])
        expect(payload.data).to eq({ uuid: model.id, full_name: model.name })
      end
    end

    describe 'when parsing data' do
      it 'calls model method when provided Symbol value' do
        allow(model).to receive(:build_data) { {} }
        expect(model).to receive(:build_data).with(action)
        payload_for(action, data: :build_data)
      end

      it 'calls block when provided block value' do
        block = lambda { |_model, _action| {} }
        expect(block).to receive(:call).with(model, action).and_return({})
        payload_for(action, data: block)
      end

      it 'uses provided data when passed a Hash' do
        data = { name: 'sample name' }
        payload = payload_for(action, data: data)
        expect(payload.data).to eq(data)
      end
    end
  end

  private

  def payload_for(*args)
    PubSubModelSync::Publisher.new(model, *args).payload
  end
end
