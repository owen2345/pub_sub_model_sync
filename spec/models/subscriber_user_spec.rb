# frozen_string_literal: true

RSpec.describe SubscriberUser do
  let(:message_processor) { PubSubModelSync::MessageProcessor }
  it 'crud publisher settings' do
    settings = SubscriberUser2.ps_msync_subscriber_settings
    expected_settings = { attrs: %i[name], as_class: 'User', id: :id }
    expect(settings).to include expected_settings
  end

  describe 'subscriptions' do
    describe 'CRUD' do
      describe 'create' do
        let(:id_model) { 10 }
        let(:data) { { name: 'Test user', email: 'sample email', age: 10 } }
        let(:attrs) do
          pub_sub_attrs_builder('SubscriberUser', :create, id_model)
        end
        let(:sender) { message_processor.new(data, attrs) }
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
        let(:data) { { name: 'Test user', email: 'sample email', age: 10 } }
        let(:attrs) do
          pub_sub_attrs_builder('SubscriberUser', :update, model.id)
        end
        let(:sender) { message_processor.new(data, attrs) }
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
        let(:data) { { name: 'Test user', email: 'sample email', age: 10 } }
        let(:attrs) do
          pub_sub_attrs_builder('SubscriberUser', :destroy, model.id)
        end
        let(:sender) { message_processor.new(data, attrs) }
        it 'destroy model' do
          sender.process
          expect { model.reload }.to raise_error(ActiveRecord::RecordNotFound)
        end
      end
    end

    describe 'custom crud subscriptions' do
      let(:model_klass) { SubscriberUser2 }
      let(:model) { model_klass.create(name: 'orig_name', email: 'orig_email') }
      let(:data) { { name: 'Test user', email: 'sample email', age: 10 } }
      let(:destroy_attrs) { pub_sub_attrs_builder('User', :destroy, model.id) }
      let(:update_attrs) { pub_sub_attrs_builder('User', :update, model.id) }
      it 'do not call non accepted actions (excluded destroy)' do
        sender = message_processor.new(data, destroy_attrs)
        sender.process
        expect_any_instance_of(model_klass).not_to receive(:destroy!)
      end

      it 'Listen to custom class name (SubscriberUser2 from Class User)' do
        sender = message_processor.new(data, update_attrs)
        sender.process
        model.reload
        expect(model.name).to eq data[:name]
      end
    end

    describe 'class subscriptions' do
      let(:model_klass) { SubscriberUser }
      let(:data) { { msg: 'Hello' } }
      it 'basic listener' do
        expect(model_klass).to receive(:greeting).with(data)
        msg_attrs = pub_sub_attrs_builder(model_klass.name, :greeting)
        sender = message_processor.new(data, msg_attrs)
        sender.process
      end
      it 'custom action_name (:greeting2 into :greeting)' do
        expect(model_klass).to receive(:greeting).with(data)
        msg_attrs = pub_sub_attrs_builder(model_klass.name, :greeting2)
        sender = message_processor.new(data, msg_attrs)
        sender.process
      end
      it 'custom class_name (User as SubscriberUser)' do
        expect(model_klass).to receive(:greeting).with(data)
        msg_attrs = pub_sub_attrs_builder('User', :greeting3)
        sender = message_processor.new(data, msg_attrs)
        sender.process
      end
    end
  end
end
