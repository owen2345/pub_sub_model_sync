# frozen_string_literal: true

RSpec.describe PubSubModelSync::PayloadCacheOptimizer do
  let(:data) { { id: 10, title: 'title', descr: 'descr value', qty: 100 } }
  let(:info) { { klass: 'SomeClass', action: :action } }
  let(:headers) { { cache: { required: [:id] } } }
  let(:payload) { PubSubModelSync::Payload.new(data.clone, info, headers) }
  let(:inst) { described_class.new(payload) }
  before do
    allow(Rails).to receive(:cache).and_return(double('Cache', read: nil, write: nil))
  end

  it 'does not check cached payload if cache was disabled' do
    allow(PubSubModelSync::Config).to receive(:skip_cache).and_return(true)
    expect(inst).not_to receive(:previous_payload_data)
    inst.call
  end

  it 'does not update payload data if delivering first time (no previous payload)' do
    stub_cached_payload(nil)
    expect(payload).not_to receive(:data=)
    inst.call
  end

  it 'returns :already_sent if current payload is equal to previous delivered payload' do
    stub_cached_payload(payload.data.clone)
    expect(inst.call).to eq(:already_sent)
  end

  describe 'when delivering payload with different values' do
    let(:old_data) { payload.data.clone.merge({ title: 'old title', descr: 'old descr', qty: 100 }) }
    before do
      stub_cached_payload(old_data)
    end

    it 'saves as cache the current payload data' do
      expect(Rails.cache).to receive(:write).with(inst.cache_key, payload.data, anything)
      inst.call
    end

    it 'always includes required fields even if they were not changed' do
      inst.call
      expect(payload.data).to match(hash_including(id: 10))
    end

    it 'removes non changed fields' do
      inst.call
      expect(payload.data).to match(hash_excluding(:qty))
    end

    it 'keeps the updated fields' do
      inst.call
      expect(payload.data).to match(hash_including(:title, :descr))
    end

    it 'does not apply payload optimization if not defined' do
      allow(inst).to receive(:optimization_enabled?).and_return(false)
      expect(inst).not_to receive(:optimize_payload)
    end
  end

  def stub_cached_payload(cached_data)
    allow(Rails.cache).to receive(:read).with(inst.cache_key).and_return(cached_data)
  end
end
