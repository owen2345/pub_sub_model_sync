# frozen_string_literal: true

RSpec.describe PubSubModelSync::Payload do
  let(:data) { { val: 'sample' } }
  let(:attrs) { { klass: 'User', action: :create } }
  let(:inst) { described_class.new(data, attrs) }

  it 'includes :data in hash format' do
    expect(inst.to_h[:data]).to eq(data)
  end

  it 'includes :attributes in hash format' do
    expect(inst.to_h[:attributes]).to eq(attrs)
  end

  it 'includes :headers in hash format' do
    expect(inst.to_h.key?(:headers)).to be_truthy
  end

  it 'includes a unique ID' do
    expect(inst.to_h[:headers][:uuid].present?).to be_truthy
  end
end
