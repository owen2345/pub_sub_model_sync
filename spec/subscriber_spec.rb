# frozen_string_literal: true

RSpec.describe PubSubModelSync::Subscriber do
  let(:message) { { name: 'sample name', email: 'sample email', age: '10' } }
  let(:payload_attrs) { { klass: 'Tester', action: :test } }
  let(:payload) { PubSubModelSync::Payload.new(message, payload_attrs) }
  describe 'class message' do
    let(:action) { :action_name }
    let(:model_klass) { SubscriberUser }
    let(:settings) { { direct_mode: true } }
    let(:inst) do
      described_class.new(model_klass.name, action, settings: settings)
    end

    it 'calls received action' do
      model_klass.create_class_method(action) do
        expect(model_klass).to receive(action).with(message)
        inst.process!(payload)
      end
    end
  end

  describe 'model message' do
    let(:action) { :create }
    let(:model_klass) { SubscriberUser }
    let(:settings) { { direct_mode: false } }
    let(:attrs) { %i[name email] }
    let(:inst) do
      described_class.new(model_klass.name, action, attrs: attrs,
                                                    settings: settings)
    end

    describe 'call action' do
      it 'calls :save! method when received :create action' do
        expect_any_instance_of(model_klass).to receive(:save!)
        inst.process!(payload)
      end
      describe 'when update' do
        let(:action) { :update }
        let!(:model) { model_klass.create(message) }
        before do
          inst.action = action
          allow(inst).to receive(:find_model).and_return(model)
        end
        after { inst.process!(payload) }

        it 'updates with received data' do
          message[:name] = 'Changed Name'
          expect_any_instance_of(model_klass).to receive(:save!)
        end

        it 'does not update if no changes' do
          expect_any_instance_of(model_klass)
            .to receive(:ps_subscriber_changed?).and_return(false)
          expect_any_instance_of(model_klass).not_to receive(:save!)
        end
      end

      it 'calls :destroy when destroy action received' do
        action = :destroy
        inst.action = action
        expect_any_instance_of(model_klass).to receive(:destroy!)
        inst.process!(payload)
      end

      it 'does not call action when :ps_before_save_sync returns :cancel' do
        action = :destroy
        inst.action = action
        allow_any_instance_of(model_klass).to receive(:ps_before_save_sync) { :cancel }
        expect_any_instance_of(model_klass).not_to receive(:destroy!)
        inst.process!(payload)
      end

      it 'assigns processing payload to the model' do
        expect_any_instance_of(model_klass).not_to receive(:ps_processed_payload).with(payload)
        inst.process!(payload)
      end
    end

    describe 'find model' do
      it 'supports for custom finder' do
        model = model_klass.new
        model_klass.create_class_method(:ps_find_model) do
          expect(model_klass).to receive(:ps_find_model).with(message) { model }
          inst.process!(payload)
        end
      end

      it 'supports for custom identifier' do
        model = model_klass.create(message)
        inst.identifiers = %i[name]
        allow(model_klass).to receive(:where).and_call_original
        expect(model_klass).to receive(:where).with(name: model.name)
        inst.process!(payload)
      end

      it 'supports for multiple identifiers' do
        model = model_klass.create(message)
        inst.identifiers = %i[name email]
        allow(model_klass).to receive(:where).and_call_original
        args = { name: model.name, email: model.email }
        expect(model_klass).to receive(:where).with(args)
        inst.process!(payload)
      end
    end

    describe 'populate model' do
      it 'extracts all permitted attrs' do
        model = model_klass.create(name: 'original name')
        allow(inst).to receive(:find_model) { model }
        inst.attrs = %i[name email]
        inst.process!(payload)
        inst.attrs.each do |attr|
          expect(model.send(attr)).to eq message[attr]
        end
      end

      it 'does not touch not permitted attrs' do
        original_name = 'original name'
        model = model_klass.create(name: original_name)
        allow(inst).to receive(:find_model) { model }
        inst.attrs = %i[email]
        inst.process!(payload)
        expect(model.name).to eq original_name
      end
    end
  end

  private

  def stub_saved(model_klass, flag)
    allow_any_instance_of(model_klass).to receive(:changed?).and_return(flag)
  end
end
