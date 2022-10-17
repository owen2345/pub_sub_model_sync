# frozen_string_literal: true

RSpec.describe PubSubModelSync::MessagePublisher do
  let(:publisher_klass) { 'PublisherUser' }
  let(:inst) { described_class }
  let(:connector) { inst.connector }
  let(:payload_klass) { PubSubModelSync::Payload }

  let(:model) { PublisherUser.new(id: 1, name: 'name', email: 'email', age: 10) }
  let(:action) { :update }

  describe 'when ensuring if payload can be published' do
    it 'does not publish payload if :on_before_publish returns :cancel' do
      allow(inst.config.on_before_publish).to receive(:call).and_return(:cancel)
      allow(inst).to receive(:log)
      expect(inst).to receive(:log).with(include('Publish cancelled by'))
      expect(connector).not_to receive(:publish)
      inst.publish_data(publisher_klass, {}, :greeting)
    end

    describe 'when checking previous delivered payload' do
      let(:headers) { { cache: { required: [:id] } } }
      let(:checker_klass) { PubSubModelSync::PayloadCacheOptimizer }
      after { inst.publish_data(publisher_klass, {}, :greeting, headers: headers) }

      it 'does not publish payload if already delivered similar payload' do
        allow_any_instance_of(checker_klass).to receive(:call).and_return(:already_sent)
        expect(connector).not_to receive(:publish)
      end

      it 'publishes payload if not delivered yet' do
        allow_any_instance_of(checker_klass).to receive(:call, &:payload)
        expect(connector).to receive(:publish)
      end
    end
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

  describe '.publish_model' do
    describe '#publish' do
      it 'publishes payload to connector' do
        expect(connector).to receive(:publish).with(be_kind_of(payload_klass))
        inst.publish_model(model, action)
      end
    end

    describe 'callbacks' do
      describe '#ps_before_publish' do
        it 'calls callback method before publishing model' do
          expect(model).to receive(:ps_before_publish).with(action, anything)
          inst.publish_model(model, action)
        end

        it 'does not publish if callback returns :cancel' do
          allow(model).to receive(:ps_before_publish).and_return(:cancel)
          expect(connector).not_to receive(:publish)
          expect(model).not_to receive(:ps_after_publish)
          inst.publish_model(model, action)
        end
      end

      describe '#ps_after_publish' do
        it 'calls callback method after publishing' do
          expect(model).to receive(:ps_after_publish).with(action, any_args)
          inst.publish_model(model, action)
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

    it 'includes the provided payload headers for each payload' do
      payload_key = 'my-key'
      expect_publish_with_headers({ key: payload_key }, times: 2) do
        described_class.transaction('any-key', headers: { key: payload_key }) do
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

    it 'uses the same ordering_key when publishing from :ps_before_publish callback' do
      key = 'model-key'
      allow(model).to receive(:ps_before_publish) do
        inst.publish_data(publisher_klass, {}, action)
      end
      expect_publish_with_headers({ ordering_key: key }, times: 2) do
        inst.publish_model(model, action, data: {}, headers: { ordering_key: key })
      end
    end

    it 'uses first payload\'s ordering_key if transaction key is empty' do
      key = 'trans_key'
      expect_publish_with_headers({ ordering_key: key }, times: 2) do
        described_class.transaction(nil) do
          inst.publish_data('Sample', {}, :sample_action, headers: { ordering_key: key })
          inst.publish_data('Sample', {}, :sample2, headers: { ordering_key: 'any' })
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
