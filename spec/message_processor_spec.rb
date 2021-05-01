# frozen_string_literal: true

RSpec.describe PubSubModelSync::MessageProcessor do
  let(:action) { :create }
  let(:payload) { PubSubModelSync::Payload.new({}, { klass: 'SubscriberUser', action: action }) }
  let(:inst) { described_class.new(payload) }
  let(:subscriber_klass) { PubSubModelSync::Subscriber }
  let(:s_processor) { double('SProcessor', call: true) }

  before do
    allow(PubSubModelSync::SubscriberProcessor).to receive(:new).and_return(s_processor)
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
        expect(PubSubModelSync::SubscriberProcessor).to receive(:new).with(subscriber, payload)
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

    it 'retries many times if error "could not obtain a database connection ..."' do
      times = 5
      stub_with_subscriber(action) do
        allow(s_processor).to receive(:call).and_raise(ActiveRecord::ConnectionTimeoutError)
        expect(s_processor).to receive(:call).exactly(times + 1).times
        suppress(Exception) { inst.process }
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

    describe 'when notifying' do
      let(:subscriber) { subscriber_klass.new('SubscriberUser', action) }
      before { allow(inst).to receive(:filter_subscribers).and_return([subscriber]) }
      after { inst.process }

      it 'notifies #on_before_processing hook before processing' do
        args = [payload, hash_including(subscriber: be_kind_of(subscriber_klass))]
        expect(inst.config.on_before_processing).to receive(:call).with(*args)
      end

      it 'notifies #on_success_processing hook when success' do
        args = [payload, hash_including(subscriber: be_kind_of(subscriber_klass))]
        expect(inst.config.on_success_processing).to receive(:call).with(*args)
      end

      describe 'when failed' do
        before do
          allow(s_processor).to receive(:call).and_raise('error processing')
          allow(inst.config).to receive(:log)
        end

        it 'notifies #on_error_processing hook when failed' do
          exp_info = hash_including(payload: payload)
          expect(inst.config.on_error_processing).to receive(:call).with(be_kind_of(StandardError), exp_info)
        end

        it 'skips error logs when #on_error_processing returns :skip_log' do
          allow(inst.config.on_error_processing).to receive(:call).and_return(:skip_log)
          expect(inst.config).not_to receive(:log).with(include('Error processing message'))
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
