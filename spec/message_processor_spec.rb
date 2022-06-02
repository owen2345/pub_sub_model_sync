# frozen_string_literal: true

RSpec.describe PubSubModelSync::MessageProcessor do
  let(:action) { :create }
  let(:payload) { PubSubModelSync::Payload.new({}, { klass: 'SubscriberUser', action: action }) }
  let(:inst) { described_class.new(payload) }
  let(:subscriber_klass) { PubSubModelSync::Subscriber }
  let(:s_processor) { double('SProcessor', call: true) }

  before do
    allow(PubSubModelSync::RunSubscriber).to receive(:new).and_return(s_processor)
    allow(Process).to receive(:exit!)
    allow(inst).to receive(:sleep)
    allow(inst).to receive(:log)
  end

  it 'supports for deprecated initializer' do
    inst = described_class.new({}, 'User', :create)
    expect([inst.payload.klass, inst.payload.action]).to eq ['User', :create]
  end

  describe 'subscriber exists' do
    it 'subscribes with basic data' do
      stub_with_subscriber(action) do |subscriber|
        expect(inst).to receive(:run_subscriber).with(subscriber)
        inst.process
      end
    end

    it 'calls subscriber processor' do
      stub_with_subscriber(action) do |subscriber|
        expect(PubSubModelSync::RunSubscriber).to receive(:new).with(subscriber, payload)
        inst.process
      end
    end

    it 'subscribes with custom klass' do
      custom_klass = 'CustomClass'
      payload.info[:klass] = custom_klass
      stub_with_subscriber(action, settings: { from_klass: custom_klass }) do |subscriber|
        expect(inst).to receive(:run_subscriber).with(subscriber)
        inst.process
      end
    end

    it 'does not process if returns :cancel from :on_before_processing' do
      allow(inst.config.on_before_processing).to receive(:call).and_return(:cancel)
      stub_with_subscriber(action) do
        allow(inst).to receive(:log)
        expect(inst).to receive(:log).with(include('process message cancelled'))
        expect(s_processor).not_to receive(:call)
        inst.process
      end
    end

    describe 'when failed' do
      let(:times) { 5 }

      it 'reconnects DB if DB connection lost' do
        stub_with_subscriber(action) do
          allow(s_processor).to receive(:call).and_raise('lost connection')
          expect(ActiveRecord::Base.connection).to receive(:reconnect!).exactly(times).times
          suppress(Exception) { inst.process }
        end
      end

      it 'reconnects DB timeout error' do
        allow(StandardError).to receive(:name).and_return('ActiveRecord::ConnectionTimeoutError')
        stub_with_subscriber(action) do
          allow(s_processor).to receive(:call).and_raise('db timeout')
          expect(ActiveRecord::Base.connection).to receive(:reconnect!).exactly(times).times
          suppress(Exception) { inst.process }
        end
      end

      it 'exits the system when retried 5 times' do
        stub_with_subscriber(action) do
          allow(s_processor).to receive(:call).and_raise('lost connection')
          expect(Process).to receive(:exit!)
          suppress(Exception) { inst.process }
        end
      end

      it 'notifies error message when failed processing notification' do
        stub_with_subscriber(action) do
          allow(s_processor).to receive(:call).and_raise('any error')
          expect(inst).to receive(:notify_error).once
          suppress(Exception) { inst.process }
        end
      end
    end

    describe 'when notifying' do
      let(:subscriber) { subscriber_klass.new('SubscriberUser', action) }
      before { allow(inst).to receive(:filter_subscribers).and_return([subscriber]) }
      after { |test| inst.process unless test.metadata[:skip_after] }

      it 'notifies #on_before_processing hook before processing' do
        args = [payload, hash_including(subscriber: be_kind_of(subscriber_klass))]
        expect(inst.config.on_before_processing).to receive(:call).with(*args)
      end

      it 'notifies #on_success_processing hook when success' do
        args = [payload, hash_including(subscriber: be_kind_of(subscriber_klass))]
        expect(inst.config.on_success_processing).to receive(:call).with(*args)
      end

      describe '#on_error_processing: when failed' do
        let(:error_msg) { 'error processing' }
        before do
          allow(s_processor).to receive(:call).and_raise(error_msg)
          allow(inst.config).to receive(:log)
        end

        it 'calls #on_error_processing hook for a custom retrying (like auto-retry via sidekiq)' do
          exp_info = hash_including(payload: payload)
          expect(inst.config.on_error_processing).to receive(:call).with(be_kind_of(StandardError), exp_info)
        end

        it 'skips error logs when #on_error_processing returns :skip_log' do
          allow(inst.config.on_error_processing).to receive(:call).and_return(:skip_log)
          expect(inst.config).not_to receive(:log).with(include(error_msg))
        end

        it '#on_error_processing hook raises exception-error by default to auto-retry by pubsub', skip_after: true do
          allow(inst.config.on_error_processing).to receive(:call).and_call_original
          expect { inst.process }.to raise_error(error_msg)
        end
      end
    end
  end

  it 'does not process if no subscriber found: different klass' do
    payload.info[:klass] = 'UnknownClass'
    stub_with_subscriber(action) do |subscriber|
      expect(inst).not_to receive(:run_subscriber).with(subscriber)
      inst.process
    end
  end

  it 'does not process if no subscriber found: different action' do
    payload.info[:action] = :unknown_action
    stub_with_subscriber(action) do |subscriber|
      expect(inst).not_to receive(:run_subscriber).with(subscriber)
      inst.process
    end
  end
end
