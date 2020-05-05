# frozen_string_literal: true

RSpec.describe PubSubModelSync::MessagePublisher do
  let(:publisher_klass) { 'PublisherUser' }
  let(:inst) { described_class }
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

    describe '#publish' do
      it 'default publisher' do
        expect(connector).to receive(:publish)
        inst.publish_model(model, action)
      end

      it 'custom publisher' do
        attrs = %i[name email]
        publisher = PubSubModelSync::Publisher.new(attrs, model.class.name)
        exp_data = attrs.map { |k| [k, model.send(k)] }.to_h
        exp_attrs = hash_including(:action, :klass)
        expect(connector).to receive(:publish).with(exp_data, exp_attrs)
        inst.publish_model(model, action, publisher)
      end
    end

    describe 'callbacks' do
      describe '#ps_before_sync' do
        it 'call method' do
          expect(model).to receive(:ps_before_sync).with(action, anything)
          inst.publish_model(model, action)
        end

        it 'does not publish if return :cancel' do
          allow(model).to receive(:ps_before_sync).and_return(:cancel)
          expect(connector).not_to receive(:publish)
          expect(model).not_to receive(:ps_after_sync)
          inst.publish_model(model, action)
        end
      end

      describe '#ps_skip_sync?' do
        it 'call method' do
          expect(model).to receive(:ps_skip_sync?).with(action)
          inst.publish_model(model, action)
        end

        it 'does not publish if return :cancel' do
          allow(model).to receive(:ps_skip_sync?).and_return(true)
          expect(connector).not_to receive(:publish)
          expect(model).not_to receive(:ps_before_sync)
          inst.publish_model(model, action)
        end
      end

      describe '#ps_after_sync' do
        it 'call method' do
          expect(model).to receive(:ps_after_sync).with(action, any_args)
          publisher = model.class.ps_publisher(action)
          inst.publish_model(model, action, publisher)
        end
      end
    end
  end
end
