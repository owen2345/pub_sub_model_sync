# frozen_string_literal: true

RSpec.describe PubSubModelSync::MessageProcessor do
  let(:subs_klass) { PubSubModelSync::Subscriber }
  let(:payload) { PubSubModelSync::Payload.new({}, { klass: 'SampleUser', action: :create }) }
  let(:inst) { described_class.new(payload) }
  let!(:subscriber) do
    subs_klass.new(payload.klass, payload.action, settings: { direct_mode: true })
  end

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

    describe 'when notifying' do
      before do
        allow(inst).to receive(:filter_subscribers).and_return([subscriber])
        allow(subscriber).to receive(:eval_message)
      end
      after { inst.process }

      it 'notifies #on_process_success hook when success' do
        args = [payload, be_kind_of(PubSubModelSync::Subscriber)]
        expect(inst.config.on_process_success).to receive(:call).with(*args)
      end

      describe 'when failed' do
        before do
          allow(subscriber).to receive(:eval_message).and_raise('error processing')
          allow(inst.config).to receive(:log)
        end
        it 'notifies #on_process_error hook when failed' do
          expect(inst.config.on_process_error).to receive(:call).with(be_kind_of(StandardError), payload)
        end
        it 'skips error logs when #on_process_error returns :skip_log' do
          allow(inst.config.on_process_error).to receive(:call).and_return(:skip_log)
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
