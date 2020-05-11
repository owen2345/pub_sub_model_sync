# frozen_string_literal: true

RSpec.describe PubSubModelSync::Subscriber do
  let(:message) { { name: 'sample name', email: 'sample email', age: '10' } }
  describe 'class message' do
    let(:action) { :action_name }
    let(:model_klass) { SubscriberUser }
    let(:settings) { { direct_mode: true } }
    let(:inst) do
      described_class.new(model_klass.name, action, settings: settings)
    end

    it 'call action' do
      model_klass.create_class_method(action) do
        expect(model_klass).to receive(action).with(message)
        inst.eval_message(message)
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
      it 'when create' do
        expect_any_instance_of(model_klass).to receive(:save!)
        inst.eval_message(message)
      end
      describe 'when update' do
        let(:action) { :update }
        let!(:model) { model_klass.create(message) }
        before do
          inst.action = action
          allow(inst).to receive(:find_model).and_return(model)
        end
        after { inst.eval_message(message) }

        it 'update with changes' do
          message[:name] = 'Changed Name'
          expect_any_instance_of(model_klass).to receive(:save!)
        end
        it 'update without changes' do
          expect_any_instance_of(model_klass).not_to receive(:save!)
        end
      end

      it 'when destroy' do
        action = :destroy
        inst.action = action
        expect_any_instance_of(model_klass).to receive(:destroy!)
        inst.eval_message(message)
      end
    end

    describe 'find model' do
      it 'custom finder' do
        model = model_klass.new
        model_klass.create_class_method(:ps_find_model) do
          expect(model_klass).to receive(:ps_find_model).with(message) { model }
          inst.eval_message(message)
        end
      end

      it 'find by custom attr' do
        model = model_klass.create(message)
        inst.settings[:id] = :name
        allow(model_klass).to receive(:where).and_call_original
        expect(model_klass).to receive(:where).with(name: model.name)
        inst.eval_message(message)
      end

      it 'find by multiple attribute' do
        model = model_klass.create(message)
        inst.settings[:id] = %i[name email]
        allow(model_klass).to receive(:where).and_call_original
        args = { name: model.name, email: model.email }
        expect(model_klass).to receive(:where).with(args)
        inst.eval_message(message)
      end
    end

    describe 'populate model' do
      it 'all permitted attrs' do
        model = model_klass.create(name: 'original name')
        allow(inst).to receive(:find_model) { model }
        inst.attrs = %i[name email]
        inst.eval_message(message)
        inst.attrs.each do |attr|
          expect(model.send(attr)).to eq message[attr]
        end
      end

      it 'do not touch not permitted attrs' do
        original_name = 'original name'
        model = model_klass.create(name: original_name)
        allow(inst).to receive(:find_model) { model }
        inst.attrs = %i[email]
        inst.eval_message(message)
        expect(model.name).to eq original_name
      end
    end
  end

  private

  def stub_saved(model_klass, flag)
    allow_any_instance_of(model_klass).to receive(:changed?).and_return(flag)
  end
end
