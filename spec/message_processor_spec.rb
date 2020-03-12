# frozen_string_literal: true

RSpec.describe PubSubModelSync::MessageProcessor do
  let(:listener_klass) { 'SubscriberUser' }
  describe 'class message' do
    let(:data) { { greeting: 'Hello' } }
    let(:listener_action) { :greeting } # subscribed in SubscriberUser model
    let(:inst) do
      described_class.new(data, listener_klass, listener_action)
    end
    describe '.filter_listeners' do
      it 'with listeners' do
        expect(inst.send(:filter_listeners).any?).to be_truthy
      end
      it 'without class listeners' do
        inst = described_class.new(data, 'Invalid', 'greeting')
        expect(inst.send(:filter_listeners).any?).to be_falsey
      end
      it 'without action listeners' do
        inst = described_class.new(data, 'SubscriberUser', 'inv')
        expect(inst.send(:filter_listeners).any?).to be_falsey
      end
    end
    describe '.eval_message' do
      it 'receive listener to call action' do
        listener_info = hash_including(klass: listener_klass,
                                       action: listener_action)
        allow(inst).to receive(:call_class_listener)
        expect(inst).to receive(:call_class_listener).with(listener_info)
        inst.process
      end
      it 'call model class method' do
        klass = listener_klass.constantize
        expect(klass).to receive(listener_action).with(data)
        inst.process
      end
      it 'log if error calling action' do
        error_msg = 'Error in class method'
        klass = listener_klass.constantize
        allow(klass).to receive(listener_action).and_raise(error_msg)
        allow(inst).to receive(:log)
        expect(inst).to receive(:log).with(include(error_msg), anything)
        inst.process
      end
    end
  end

  describe 'crud message' do
    let(:data) { {} }
    let(:action) { :update }
    describe '.filter_listeners' do
      let(:listener_klass) { 'SubscriberUser2' }
      let(:listener_klass) { 'User' }
      it 'listeners only for enabled actions' do
        inst = described_class.new(data, listener_klass, action)
        expect(inst.send(:filter_listeners).any?).to be_truthy
      end
      it 'no listeners for excluded actions' do
        inst = described_class.new(data, listener_klass, :create)
        expect(inst.send(:filter_listeners).any?).to be_falsey
      end
      it 'no listeners for non subscribed models' do
        inst = described_class.new(data, 'Unknown', :create)
        expect(inst.send(:filter_listeners).any?).to be_falsey
      end
    end

    describe '.eval_message' do
      let(:listener_klass) { 'SubscriberUser2' }
      let(:inst) { described_class.new(data, 'User', action) }
      it 'receive listener to call action' do
        listener_info = hash_including(klass: listener_klass, action: action)
        expect(inst).to receive(:call_listener).with(listener_info)
        inst.process
      end
      it 'call model method' do
        klass = listener_klass.constantize
        expect_any_instance_of(klass).to receive(:save!)
        inst.process
      end
      it 'log if error calling action' do
        error_msg = 'Error in class method'
        klass = listener_klass.constantize
        expect_any_instance_of(klass).to receive(:save!).and_raise(error_msg)
        allow(inst).to receive(:log)
        expect(inst).to receive(:log).with(include(error_msg), anything)
        inst.process
      end
    end
  end
end
