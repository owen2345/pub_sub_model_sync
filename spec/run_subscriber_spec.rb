# frozen_string_literal: true

RSpec.describe PubSubModelSync::RunSubscriber do
  let(:model_klass) { SubscriberUser }
  let(:message) { { name: 'sample name', email: 'sample email', age: '10' } }

  describe 'class message' do
    let(:action) { :hello }
    let(:subscriber) { PubSubModelSync::Subscriber.new(model_klass.name, action, settings: { mode: :klass }) }
    let(:payload) { PubSubModelSync::Payload.new(message, { klass: model_klass.name, action: action }) }
    after { described_class.new(subscriber, payload).call }

    describe 'when checking conditions' do
      it 'ensures if condition: block' do
        block = -> {}
        subscriber.settings[:if] = block
        expect(block).to receive(:call).with(no_args)
      end

      it 'ensures if condition: method name' do
        method_name = :method_name
        subscriber.settings[:if] = method_name
        expect(model_klass).to receive(method_name).with(no_args)
      end

      it 'ensures unless condition: block' do
        block = -> {}
        subscriber.settings[:unless] = block
        expect(block).to receive(:call).with(no_args)
      end

      it 'ensures unless condition: method name' do
        method_name = :method_name
        subscriber.settings[:unless] = method_name
        expect(model_klass).to receive(method_name).with(no_args)
      end
    end

    describe 'when calling action' do
      it 'calls received action' do
        expect(model_klass).to receive(action).with(payload.data)
      end

      it 'calls custom action if defined' do
        custom_method_name = :custom_method_name
        subscriber.settings[:to_action] = custom_method_name
        expect(model_klass).to receive(custom_method_name).with(payload.data)
      end

      it 'calls custom Proc if defined' do
        mock = double('Proc', call: true)
        proc = ->(*args) { mock.call(*args) }
        subscriber.settings[:to_action] = proc
        expect(mock).to receive(:call).with(payload.data)
      end
    end
  end

  describe 'model actions' do
    let(:action) { :print_name }
    let(:model) { SubscriberUser.new }
    let(:payload) { PubSubModelSync::Payload.new(message, { klass: 'SubscriberUser', action: action }) }
    let(:subscriber) { PubSubModelSync::Subscriber.new('SubscriberUser', action, settings: { mode: :model }) }
    before do
      allow_any_instance_of(described_class).to receive(:find_model).and_return(model)
      allow(model).to receive(action)
    end

    describe 'when finding model' do
      before do
        allow_any_instance_of(described_class).to receive(:find_model).and_call_original
        allow(model_klass).to receive(:where).and_return(double(first_or_initialize: model))
      end
      after do |spec|
        described_class.new(subscriber, payload).call unless spec.metadata[:skip_after]
      end

      it 'single attribute' do
        subscriber.settings[:id] = :email
        expect(model_klass).to receive(:where).with(hash_including(email: message[:email]))
      end

      it 'supports for multiple attrs' do
        subscriber.settings[:id] = %i[name email]
        expect(model_klass).to receive(:where).with(hash_including(email: message[:email], name: message[:name]))
      end

      it 'supports for aliasing' do
        subscriber.settings[:id] = %w[email name:full_name]
        exp_attrs = { full_name: message[:name], email: message[:email] }
        expect(model_klass).to receive(:where).with(hash_including(exp_attrs))
      end

      it 'calls :ps_find_model for a custom finder' do
        allow(model_klass).to receive(:respond_to?).with(:ps_find_model).and_return(true)
        expect(model_klass).to receive(:ps_find_model).and_return(model)
      end

      it 'raises error when no values provided for identifiers', skip_after: true do
        subscriber.settings[:id] = :attr_not_in_payload
        expect { described_class.new(subscriber, payload).call }.to raise_error(/No values provided for identifiers/)
      end
    end

    describe 'when populating data' do
      after { described_class.new(subscriber, payload).call }

      it 'supports multiple attributes' do
        subscriber.mapping = %i[name email]
        expect(model).to receive(:name=).with(message[:name])
        expect(model).to receive(:email=).with(message[:email])
      end

      it 'supports aliasing' do
        subscriber.mapping = %i[name:full_name email:user_email]
        expect(model).to receive(:full_name=).with(message[:name])
        expect(model).to receive(:user_email=).with(message[:email])
      end
    end

    describe 'when calling action' do
      after do |spec|
        described_class.new(subscriber, payload).call unless spec.metadata[:skip_after]
      end

      it 'calls defined action' do
        expect(model).to receive(action).with(payload.data)
      end

      it 'calls provided custom method with payload data' do
        custom_method = :print_full_name
        expect(model).to receive(custom_method).with(payload.data)
        subscriber.settings[:to_action] = custom_method
      end

      it 'calls provided Proc as action with payload data' do
        mock = double('Proc', call: true)
        proc_callback = ->(*args) { mock.call(*args) }
        subscriber.settings[:to_action] = proc_callback
        expect(mock).to receive(:call).with(payload.data)
      end

      it 'calls :save! when action is create' do
        subscriber.settings[:to_action] = :create
        expect(model).to receive(:save!).with(no_args)
      end

      it 'calls :save! when action is update' do
        subscriber.settings[:to_action] = :update
        expect(model).to receive(:save!).with(no_args)
      end

      it 'calls :destroy! when action is update' do
        subscriber.settings[:to_action] = :destroy
        expect(model).to receive(:destroy!).with(no_args)
      end

      it 'raises errors when failed saving model data', skip_after: true do
        allow(model).to receive(action).and_raise('Some error')
        expect { described_class.new(subscriber, payload).call }.to raise_error('Some error')
      end

      describe 'when checking conditions' do
        [true, false].each do |condition_result|
          it "ensures if condition: block (returns #{condition_result})" do
            if_cond = ->(_model) { condition_result }
            allow(if_cond).to receive(:call).with(model).and_return(condition_result)
            subscriber.settings[:if] = if_cond
            expect(model).to receive(action).exactly(condition_result ? 1 : 0).times.with(payload.data)
          end

          it "ensures if condition: method name (returns #{condition_result})" do
            if_cond = :check_condition
            subscriber.settings[:if] = if_cond
            allow(model).to receive(if_cond).with(no_args).and_return(condition_result)
            expect(model).to receive(action).exactly(condition_result ? 1 : 0).times.with(payload.data)
          end

          it "ensures if condition: method names (returns #{condition_result})" do
            if_conds = %i[check_condition1 check_condition2]
            subscriber.settings[:if] = if_conds
            allow(model).to receive(:check_condition1).with(no_args).and_return(condition_result)
            allow(model).to receive(:check_condition2).with(no_args).and_return(condition_result)
            expect(model).to receive(action).exactly(condition_result ? 1 : 0).times.with(payload.data)
          end

          it "ensures unless condition: block (returns #{condition_result})" do
            unless_cond = ->(_model) { condition_result }
            subscriber.settings[:unless] = unless_cond
            allow(unless_cond).to receive(:call).with(model).and_return(condition_result)
            expect(model).to receive(action).exactly(condition_result ? 0 : 1).times.with(payload.data)
          end

          it "ensures unless condition: method name (returns #{condition_result})" do
            unless_cond = :check_condition
            subscriber.settings[:unless] = unless_cond
            allow(model).to receive(unless_cond).with(no_args).and_return(condition_result)
            expect(model).to receive(action).exactly(condition_result ? 0 : 1).times.with(payload.data)
          end
        end
      end
    end

    it 'calls :ps_before_save_sync callback before saving sync' do
      allow(model).to receive(:respond_to?).and_return(false)
      allow(model).to receive(:respond_to?).with(:ps_before_save_sync).and_return(true)
      expect(model).to receive(:ps_before_save_sync).with(no_args)
      described_class.new(subscriber, payload).call
    end
  end
end
