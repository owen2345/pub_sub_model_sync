# frozen_string_literal: true

RSpec.describe PubSubModelSync::MessagePublisher do
  let(:publisher_klass) { 'PublisherUser' }
  let(:inst) { described_class }
  let(:connector) { inst.connector }
  let(:payload_klass) { PubSubModelSync::Payload }

  let(:model) { PublisherUser2.new(id: 1, name: 'name', email: 'email', age: 10) }
  let(:action) { :update }

  it 'does not publish payload if :on_before_publish returns :cancel' do
    allow(inst).to receive(:log)
    allow(inst.config.on_before_publish).to receive(:call).and_return(:cancel)
    expect(inst).to receive(:log).with(include('Publish cancelled by'))
    expect(connector).not_to receive(:publish)
    inst.publish_data(publisher_klass, {}, :greeting)
  end

  describe '.publish_data' do
    let(:data) { { message: 'hello' } }
    let(:action) { :greeting }

    it 'publishes payload to connector' do
      expect(connector).to receive(:publish).with(be_kind_of(payload_klass))
      inst.publish_data(publisher_klass, data, action)
    end

    it 'includes provided header data' do
      custom_headers = { ordering_key: 'my order key', topic_name: 'my topic name' }
      expect_headers(custom_headers)
      inst.publish_data(publisher_klass, data, action, headers: custom_headers)
    end
  end

  describe '.publish_model_data: Publishes custom model actions (non crud actions)' do
    let(:data) { { message: 'hello' } }
    let(:action) { :greeting }

    it 'includes model info in the header' do
      expect_headers(key: [model.class.name, action, model.id].join('/'))
      inst.publish_model_data(model, data, action)
    end

    it 'includes provided header header' do
      headers = { key: 'custom key' }
      expect_headers(headers)
      inst.publish_model_data(model, data, action, headers: headers)
    end
  end

  describe '.publish_model' do
    describe '#publish' do
      it 'publishes payload to connector' do
        expect(connector).to receive(:publish).with(be_kind_of(payload_klass))
        inst.publish_model(model, action)
      end

      it 'uses custom publisher when provided' do
        attrs = %i[name email]
        publisher = PubSubModelSync::Publisher.new(attrs, model.class.name)
        expect(connector).to receive(:publish).with(be_kind_of(payload_klass))
        inst.publish_model(model, action, publisher: publisher)
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
          inst.publish_model(model, action, publisher: publisher)
        end
      end
    end
  end

  describe '.transaction' do
    it 'uses the same ordering key for all payload inside the transaction' do
      key = 'trans_key'
      expect_publish_with_headers({ ordering_key: key }, times: 2) do
        described_class.transaction(key) do
          inst.publish_model(model, action)
          inst.publish_data(publisher_klass, {}, action)
        end
      end
    end

    it 'resets transaction key when finished' do
      key = 'trans_key'
      custom_key = 'custom_key'
      expect_publish_with_headers({ ordering_key: custom_key }, times: 1) do
        described_class.transaction(key) do
          inst.publish_model(model, action)
        end
        inst.publish_data(publisher_klass, {}, action, headers: { ordering_key: custom_key })
      end
    end

    it 'uses the same ordering_key when publishing from :ps_before_sync callback' do
      key = 'model-key'
      allow(model).to receive(:ps_before_sync) do
        inst.publish_data(publisher_klass, {}, action)
      end
      expect_publish_with_headers({ ordering_key: key }, times: 2) do
        inst.publish_model(model, action, custom_headers: { ordering_key: key })
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
      it 'notifies #on_error_publish when error publishing' do
        args = [be_kind_of(StandardError), hash_including(payload: be_kind_of(payload_klass))]
        expect(config.on_error_publish).to receive(:call).with(*args)
        inst.publish_data(publisher_klass, {}, action)
      end

      it 'prints error message when failed publishing message' do
        expect(config).to receive(:log).with(include('Error publishing'), :error)
        inst.publish_data(publisher_klass, {}, action)
      end

      it 'skips error log when #on_error_publish returns :skip_log' do
        allow(config.on_error_publish).to receive(:call).and_return(:skip_log)
        expect(config).not_to receive(:log).with(include('Error publishing'), :error)
        inst.publish_data(publisher_klass, {}, action)
      end
    end
  end

  private

  # @param header_info (Hash)
  def expect_headers(header_info)
    exp_attrs = have_attributes(headers: hash_including(header_info))
    expect(connector).to receive(:publish).with(exp_attrs)
  end

  # @param attrs_info (Hash)
  def expect_attrs(attrs_info)
    exp_attrs = have_attributes(attributes: hash_including(attrs_info))
    expect(connector).to receive(:publish).with(exp_attrs)
  end
end
