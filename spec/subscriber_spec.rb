# frozen_string_literal: true

RSpec.describe PubSubModelSync::Subscriber do
  it 'uses klass as from_klass if not defined' do
    klass = 'Sample'
    inst = described_class.new(klass, :create)
    expect(inst.from_klass).to eq(klass)
  end

  it 'does not override from_klass if defined' do
    custom_klass = 'CustomKlass'
    inst = described_class.new('Sample', :create, settings: { from_klass: custom_klass })
    expect(inst.from_klass).to eq(custom_klass)
  end
end
