# frozen_string_literal: true

RSpec.describe PubSubModelSync::MessagePublisher do
  let(:publisher_klass) { 'PublisherUser' }
  let(:inst) { described_class }
  let(:connector) { inst.connector }
  let(:payload_klass) { PubSubModelSync::Payload }
  it '.publish_data: publishes payload to connector' do
    data = { message: 'hello' }
    action = :greeting
    expect(connector).to receive(:publish).with(be_kind_of(payload_klass))
    inst.publish_data(publisher_klass, data, action)
  end

  describe '.publish_model' do
    let(:model) { PublisherUser2.new(name: 'name', email: 'email', age: 10) }
    let(:action) { :update }

    describe '#publish' do
      it 'publishes payload to connector' do
        expect(connector).to receive(:publish).with(be_kind_of(payload_klass))
        inst.publish_model(model, action)
      end

      it 'uses custom publisher when provided' do
        attrs = %i[name email]
        publisher = PubSubModelSync::Publisher.new(attrs, model.class.name)
        expect(connector).to receive(:publish).with(be_kind_of(payload_klass))
        inst.publish_model(model, action, publisher)
      end
    end

    describe 'callbacks' do
      describe '#ps_before_sync' do
        it 'calls callback method before publishing model' do
          expect(model).to receive(:ps_before_sync).with(action, anything)
          inst.publish_model(model, action)
        end

        it 'does not publish if callback returns :cancel' do
          allow(model).to receive(:ps_before_sync).and_return(:cancel)
          expect(connector).not_to receive(:publish)
          expect(model).not_to receive(:ps_after_sync)
          inst.publish_model(model, action)
        end
      end

      describe '#ps_skip_sync?' do
        it 'calls callback method before publishing' do
          expect(model).to receive(:ps_skip_sync?).with(action)
          inst.publish_model(model, action)
        end

        it 'skips publishing when callback method returns :cancel' do
          allow(model).to receive(:ps_skip_sync?).and_return(true)
          expect(connector).not_to receive(:publish)
          expect(model).not_to receive(:ps_before_sync)
          inst.publish_model(model, action)
        end
      end

      describe '#ps_after_sync' do
        it 'calls callback method after publishing' do
          expect(model).to receive(:ps_after_sync).with(action, any_args)
          publisher = model.class.ps_publisher(action)
          inst.publish_model(model, action, publisher)
        end
      end
    end
  end

  describe 'when notifying' do
    let(:config) { inst.config }
    let(:action) { :test_action }
    before do
      allow(config).to receive(:log)
    end
    it 'notifies #on_before_publish before publish' do
      expect(config.on_before_publish).to receive(:call).with(be_kind_of(payload_klass))
      inst.publish_data(publisher_klass, {}, action)
    end
    it 'notifies #on_after_publish after published' do
      expect(config.on_after_publish).to receive(:call).with(be_kind_of(payload_klass))
      inst.publish_data(publisher_klass, {}, action)
    end
    describe 'when failed sending message' do
      before { allow(connector).to receive(:publish).and_raise('Error sending msg') }
      it 'notifies #on_publish_error when error publishing' do
        args = [be_kind_of(StandardError), be_kind_of(payload_klass)]
        expect(config.on_publish_error).to receive(:call).with(*args)
        inst.publish_data(publisher_klass, {}, action)
      end

      it 'prints error message when failed publishing message' do
        expect(config).to receive(:log).with(include('Error publishing'), :error)
        inst.publish_data(publisher_klass, {}, action)
      end

      it 'skips error log when #on_publish_error returns :skip_log' do
        allow(config.on_publish_error).to receive(:call).and_return(:skip_log)
        expect(config).not_to receive(:log).with(include('Error publishing'), :error)
        inst.publish_data(publisher_klass, {}, action)
      end
    end
  end
end
