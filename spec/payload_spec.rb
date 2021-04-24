# frozen_string_literal: true

RSpec.describe PubSubModelSync::Payload do
  let(:data) { { val: 'sample' } }
  let(:attrs) { { klass: 'User', action: :update } }
  let(:inst) { described_class.new(data, attrs) }
  let(:config) { PubSubModelSync::Config }

  it 'includes :data in hash format' do
    expect(inst.to_h[:data]).to eq(data)
  end

  it 'includes :settings in hash format' do
    expect(inst.to_h[:settings]).to eq(attrs)
  end

  it 'includes :headers in hash format' do
    expect(inst.to_h.key?(:headers)).to be_truthy
  end

  it 'includes a key' do
    expect(inst.headers[:key].present?).to be_truthy
  end

  it 'validates for required info' do
    attrs_without_klass = { action: :test }
    expect { described_class.new({}, attrs_without_klass) }
      .to raise_error(PubSubModelSync::Payload::MissingInfo)
  end

  it 'rebuilds from payload data' do
    payload_data = { data: {}, settings: { klass: 'Tester', action: :test }, headers: {} }
    res = described_class.from_payload_data(payload_data)
    expect(res).to be_kind_of(described_class)
  end

  describe 'when success process / publish' do
    describe '#process!' do
      it 'does process the payload' do
        klass = PubSubModelSync::MessageProcessor
        expect_any_instance_of(klass).to receive(:process!)
        inst.process!
      end
    end

    describe '#publish!' do
      it 'publishes the payload' do
        klass = PubSubModelSync::MessagePublisher
        expect(klass).to receive(:publish!)
        inst.publish!
      end
    end
  end

  describe 'when failed process / publish' do
    describe 'when processing' do
      before do
        klass = PubSubModelSync::MessageProcessor
        allow_any_instance_of(klass).to receive(:process!).and_raise('Invalid data')
      end

      describe '#process!' do
        it 'raises error' do
          expect { inst.process! }.to raise_error
        end
        it 'does not call #on_error_processing' do
          expect(config.on_error_processing).not_to receive(:call)
          suppress(Exception) { inst.process! }
        end
      end

      describe '#process' do
        it 'calls #on_error_processing when failed' do
          expect(config.on_error_processing).to receive(:call)
          suppress(Exception) { inst.process }
        end
      end
    end

    describe 'when publishing' do
      before do
        klass = PubSubModelSync::MessagePublisher.connector
        allow(klass).to receive(:publish).and_raise('Invalid data')
      end
      describe '#publish!' do
        it 'raises error' do
          expect { inst.publish! }.to raise_error
        end
        it 'does not call #on_error_publish' do
          expect(config.on_error_publish).not_to receive(:call)
          suppress(Exception) { inst.publish! }
        end
      end

      describe '#publish' do
        it 'calls #on_error_publish when failed' do
          expect(config.on_error_publish).to receive(:call)
          suppress(Exception) { inst.publish }
        end
      end
    end
  end
end
