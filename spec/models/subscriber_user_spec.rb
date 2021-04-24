# frozen_string_literal: true

RSpec.describe SubscriberUser do
  let(:message_processor) { PubSubModelSync::MessageProcessor }
  it 'crud publisher settings' do
    subscriber = SubscriberUser.ps_subscriber(:update)
    expect(subscriber).not_to be_nil
  end

  describe 'subscriptions' do
    describe 'CRUD' do
      describe 'create' do
        let(:id_model) { 10 }
        let(:data) { { name: 'Test user', email: 'email c', id: id_model } }
        let(:sender) do
          message_processor.new(data, 'SubscriberUser', :create)
        end
        let(:model_klass) { SubscriberUser }
        it 'save only accepted attrs' do
          sender.process
          created_model = model_klass.last
          expect(created_model.name).to eq data[:name]
        end
        it 'do not save not accepted attrs' do
          sender.process
          created_model = model_klass.last
          expect(created_model.email).not_to eq data[:email]
        end

        it 'create with same id as received' do
          sender.process
          created_model = model_klass.last
          expect(created_model.id).to eq id_model
        end
      end

      describe 'update' do
        let(:model_klass) { SubscriberUser }
        let(:model) { model_klass.create(name: 'name', email: 'email') }
        let(:data) { { name: 'Test user', email: 'email c', id: model.id } }
        let(:sender) do
          message_processor.new(data, 'SubscriberUser', :update)
        end
        before { sender.process }
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
        let(:model) { model_klass.create(name: 'name', email: 'email') }
        let(:data) { { name: 'Test user', email: 'email c', id: model.id } }
        let(:sender) do
          message_processor.new(data, 'SubscriberUser', :destroy)
        end
        it 'destroy model' do
          sender.process
          expect { model.reload }.to raise_error(ActiveRecord::RecordNotFound)
        end
      end
    end

    describe 'custom crud subscriptions' do
      let(:model_klass) { SubscriberUser }
      let(:model) { model_klass.create(name: 'orig_name', email: 'orig_email') }
      let(:data) { { name: 'Test user', id: model.id } }
      it 'do not call non accepted actions (excluded destroy)' do
        sender = message_processor.new(data, 'User', :destroy)
        sender.process
        expect_any_instance_of(model_klass).not_to receive(:destroy!)
      end

      it 'Listen to custom class name' do
        sender = message_processor.new(data, 'User', :update)
        sender.process
        model.reload
        expect(model.name).to eq data[:name]
      end
    end

    describe 'when listening custom model actions' do
      let(:data) { { name: 'Test user', id: 1 } }
      it 'receives the call in the corresponding method' do
        action = :send_welcome
        mock_ps_subscribe_custom(action) do |klass|
          expect_any_instance_of(klass).to receive(action).with(data)
          PubSubModelSync::Payload.new(data, { klass: klass.name, action: action }).process!
        end
      end

      it 'supports for custom action name' do
        source_action = :send_welcome
        action = :deliver_welcome
        mock_ps_subscribe_custom(action, from_action: source_action) do |klass|
          expect_any_instance_of(klass).to receive(action).with(data)
          PubSubModelSync::Payload.new(data, { klass: klass.name, action: source_action }).process!
        end
      end
    end

    describe 'class subscriptions' do
      let(:model_klass) { SubscriberUser }
      let(:data) { { msg: 'Hello' } }
      it 'basic listener' do
        expect(model_klass).to receive(:greeting).with(data)
        sender = message_processor.new(data, model_klass.name, :greeting)
        sender.process
      end
      it 'custom action_name (:greeting2 into :greeting)' do
        expect(model_klass).to receive(:greeting).with(data)
        sender = message_processor.new(data, model_klass.name, :greeting2)
        sender.process
      end
      it 'custom class_name (User as SubscriberUser)' do
        expect(model_klass).to receive(:greeting).with(data)
        sender = message_processor.new(data, 'User', :greeting3)
        sender.process
      end
    end
  end
end
