# frozen_string_literal: true

RSpec.describe PubSubModelSync::MessageProcessor do
  describe 'class message' do
    let(:data) { { greeting: 'Hello' } }
    let(:listener_klass) { 'SubscriberUser' }
    let(:listener_action) { :greeting } # subscribed in SubscriberUser model
    let(:attrs) { pub_sub_attrs_builder(listener_klass, listener_action) }
    let(:inst) { described_class.new(data, attrs) }
    describe '.filter_listeners' do
      it 'with listeners' do
        expect(inst.send(:filter_listeners).any?).to be_truthy
      end
      it 'without class listeners' do
        attrs = pub_sub_attrs_builder('InvalidClass', 'greeting')
        inst = described_class.new(data, attrs)
        expect(inst.send(:filter_listeners).any?).to be_falsey
      end
      it 'without action listeners' do
        attrs = pub_sub_attrs_builder('SubscriberUser', 'invalid_action')
        inst = described_class.new(data, attrs)
        expect(inst.send(:filter_listeners).any?).to be_falsey
      end
    end
    describe '.eval_message' do
      it 'call filtered class listeners' do
        listener_info = hash_including(class: listener_klass,
                                       action: listener_action.to_s)
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

  describe 'model message' do
    describe 'create' do
      let(:data) { { name: 'Test user', email: 'sample email', age: 10 } }
      let(:attrs) { pub_sub_attrs_builder('SubscriberUser', :create) }
      let(:inst) { described_class.new(data, attrs) }
      let(:model_klass) { SubscriberUser }
      before { inst.process }
      it 'save only accepted attrs' do
        inst.process
        created_model = model_klass.last
        expect(created_model.name).to eq data[:name]
      end
      it 'do not save not accepted attrs' do
        inst.process
        created_model = model_klass.last
        expect(created_model.email).not_to eq data[:email]
      end
      it 'print errors when failed' do
        error = 'Failed creating'
        allow_any_instance_of(model_klass).to receive(:save!).and_raise(error)
        allow(inst).to receive(:log)
        expect(inst).to receive(:log).with(include(error), anything)
        inst.process
      end
    end

    describe 'update' do
      let(:model_klass) { SubscriberUser }
      let(:model) { model_klass.create(name: 'orig_name', email: 'orig_email') }
      let(:data) { { name: 'Test user', email: 'sample email', age: 10 } }
      let(:attrs) { pub_sub_attrs_builder('SubscriberUser', :update, model.id) }
      let(:inst) { described_class.new(data, attrs) }
      before { inst.process }
      it 'save only accepted attrs' do
        model.reload
        expect(model.name).to eq data[:name]
      end
      it 'do not save not accepted attrs' do
        model.reload
        expect(model.email).not_to eq data[:email]
      end
    end

    describe 'destroy' do
      let(:model_klass) { SubscriberUser }
      let(:model) { model_klass.create(name: 'orig_name', email: 'orig_email') }
      let(:data) { { name: 'Test user', email: 'sample email', age: 10 } }
      let(:attrs) do
        pub_sub_attrs_builder('SubscriberUser', :destroy, model.id)
      end
      let(:inst) { described_class.new(data, attrs) }
      it 'destroy model' do
        inst.process
        expect { model.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe 'custom subscriptions' do
    let(:model_klass) { SubscriberUser2 }
    let(:model) { model_klass.create(name: 'orig_name', email: 'orig_email') }
    let(:data) { { name: 'Test user', email: 'sample email', age: 10 } }
    let(:destroy_attrs) { pub_sub_attrs_builder('User', :destroy, model.id) }
    let(:update_attrs) { pub_sub_attrs_builder('User', :update, model.id) }
    it 'do not call non accepted actions (destroy)' do
      inst = described_class.new(data, destroy_attrs)
      inst.process
      expect_any_instance_of(model_klass).not_to receive(:destroy!)
    end

    it 'Listen to custom class name (Listen SubscriberUser2 from Class User)' do
      inst = described_class.new(data, update_attrs)
      inst.process
      model.reload
      expect(model.name).to eq data[:name]
    end
  end
end
