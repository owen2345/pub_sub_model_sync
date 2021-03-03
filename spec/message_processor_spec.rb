# frozen_string_literal: true

RSpec.describe PubSubModelSync::MessageProcessor do
  let(:subs_klass) { PubSubModelSync::Subscriber }
  let(:payload) { PubSubModelSync::Payload.new({}, { klass: 'SampleUser', action: :create }) }
  let(:inst) { described_class.new(payload) }
  let!(:subscriber) do
    subs_klass.new(payload.klass, payload.action, settings: { mode: :klass })
  end
  before { allow(subscriber).to receive(:dup).and_return(subscriber) }

  it 'supports for deprecated initializer' do
    inst = described_class.new({}, 'User', :create)
    expect([inst.payload.klass, inst.payload.action]).to eq ['User', :create]
  end

  describe 'subscriber exists' do
    it 'subscribes with basic data' do
      stub_subscriber(subscriber) do
        expect(inst).to receive(:run_subscriber).with(subscriber)
        inst.process
      end
    end

    it 'subscribes with custom klass' do
      custom_klass = 'CustomClass'
      subscriber.settings[:from_klass] = custom_klass
      allow(payload).to receive(:klass) { custom_klass }
      stub_subscriber(subscriber) do
        expect(inst).to receive(:run_subscriber).with(subscriber)
        inst.process
      end
    end

    it 'subscribes with custom action' do
      custom_method = :custom_method
      subscriber.settings[:from_action] = custom_method
      allow(payload).to receive(:action) { custom_method }
      stub_subscriber(subscriber) do
        expect(inst).to receive(:run_subscriber).with(subscriber)
        inst.process
      end
    end

    it 'retries 2 times if error "could not obtain a database connection ..."' do
      times = 2
      stub_subscriber(subscriber) do
        allow(subscriber).to receive(:process!).and_raise(ActiveRecord::ConnectionTimeoutError)
        expect(subscriber).to receive(:process!).exactly(times + 1).times
        suppress(Exception) { inst.process }
      end
    end

    it 'does not process if returns :cancel from :on_before_processing' do
      allow(inst.config.on_before_processing).to receive(:call).and_return(:cancel)
      stub_subscriber(subscriber) do
        allow(inst).to receive(:log)
        expect(inst).to receive(:log).with(include('process message cancelled'))
        expect(subscriber).not_to receive(:process!)
        inst.process
      end
    end

    describe 'when notifying' do
      before do
        allow(inst).to receive(:filter_subscribers).and_return([subscriber])
        allow(subscriber).to receive(:process!)
      end
      after { inst.process }

      it 'notifies #on_before_processing hook before processing' do
        args = [payload, hash_including(subscriber: be_kind_of(PubSubModelSync::Subscriber))]
        expect(inst.config.on_before_processing).to receive(:call).with(*args)
      end

      it 'notifies #on_success_processing hook when success' do
        args = [payload, hash_including(subscriber: be_kind_of(PubSubModelSync::Subscriber))]
        expect(inst.config.on_success_processing).to receive(:call).with(*args)
      end

      describe 'when failed' do
        before do
          allow(subscriber).to receive(:process!).and_raise('error processing')
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
    allow(payload).to receive(:klass) { 'UnknownClass' }
    stub_subscriber(subscriber) do
      expect(inst).not_to receive(:run_subscriber).with(subscriber)
      inst.process
    end
  end

  it 'does not process if no subscriber found: different action' do
    allow(payload).to receive(:action) { :unknown_action }
    stub_subscriber(subscriber) do
      expect(inst).not_to receive(:run_subscriber).with(subscriber)
      inst.process
    end
  end
end
