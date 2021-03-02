# frozen_string_literal: true

RSpec.describe PublisherUser do
  let(:publisher_klass) { PubSubModelSync::MessagePublisher }
  it 'crud publisher settings' do
    info = PublisherUser2.ps_publisher(:update)
    expect(info).not_to be_nil
  end

  describe 'callbacks' do
    it '.create' do
      model = described_class.new(name: 'name')
      args = [be_a(model.class), :create]
      expect_publish_model(args)
      model.save!
    end

    it '.update' do
      model = described_class.create(name: 'name')
      model.name = 'Changed'
      args = [model, :update]
      expect_publish_model(args)
      model.save!
    end

    # TODO: implement a feature to detect changes
    #   including in virtual attrs or use cache
    xit '.update: not published if no changes' do
      model = described_class.create(name: 'name')
      args = [model, :update]
      expect_no_publish_model(args)
      model.save!
    end

    it '.destroy' do
      model = described_class.create(name: 'name')
      args = [model, :destroy]
      expect_publish_model(args)
      model.destroy!
    end

    describe 'publish only specified attrs' do
      let(:model) { PublisherUser2.create(name: 'name') }
      after { model.update(name: 'changed name') }
      it 'publishes model attributes' do
        expected_data = hash_including(:name)
        expected_attrs = hash_including(action: :update)
        expect_publish(have_attributes(data: expected_data, attributes: expected_attrs))
      end
      it 'supports ability to use methods as attributes' do
        expected_data = hash_including(:custom_name)
        expected_attrs = hash_including(action: :update)
        expect_publish(have_attributes(data: expected_data, attributes: expected_attrs))
      end
    end

    describe 'limit actions (PublisherUser2 is :update only)' do
      it 'publishes update event' do
        model = PublisherUser2.create(name: 'name')
        model.name = 'changed name'
        args = [anything, :update]
        expect_publish_model(args)
        model.save!
      end

      it 'does not publish create event' do
        model = PublisherUser2.new(name: 'name')
        args = [anything, 'create']
        expect_no_publish_model(args)
        model.save!
      end
    end

    describe 'when publisher is disabled' do
      it 'does not publish if disabled' do
        allow(PubSubModelSync::Config.disabled_callback_publisher).to receive(:call) { true }
        expect(publisher_klass).not_to receive(:publish_model)
        PublisherUser.create(name: 'name')
      end

      it 'publishes if not disabled' do
        allow(PubSubModelSync::Config.disabled_callback_publisher).to receive(:call) { false }
        expect(publisher_klass).to receive(:publish_model)
        PublisherUser.create(name: 'name')
      end
    end

    describe 'when grouping all sub syncs', truncate: true do
      it 'uses the same ordering_key for all syncs' do
        model = mock_publisher_callback(:after_update, { name: 'sample' }, :create!) do
          PubSubModelSync::MessagePublisher.publish_data('Test', {}, :changed)
        end
        key = PubSubModelSync::Publisher.ordering_key_for(model)
        expect_publish_with_headers({ ordering_key: key }, times: 2) do
          model.update!(name: 'changed')
        end
      end

      it 'restores parent ordering_key when finished' do
        parent_key = 'parent_key'
        model = mock_publisher_callback(:after_update, { name: 'sample' }, :create!)
        publisher_klass.transaction(parent_key) do
          model.update!(name: 'changed')
          expect(publisher_klass.transaction_key).to eq parent_key
        end
      end

      it 'restores transaction_key when failed' do
        mock_publisher_callback(:after_update, { name: 'sample' }, :create!) do
          raise 'failed saving'
        end
        expect(publisher_klass.transaction_key).to be_nil
      end
    end
  end

  describe 'methods' do
    describe '#ps_skip_callback?' do
      it 'cancels push notification' do
        model = PublisherUser2.create(name: 'name')
        model.name = 'changed name'
        args = [anything, 'update']
        allow(model).to receive(:ps_skip_callback?).and_return(true)
        expect_no_publish_model(args)
        model.save!
      end
    end

    describe '.ps_perform_sync' do
      let(:model) { PublisherUser.new(name: 'name') }
      let(:attrs) { %i[name] }
      it 'performs manual create sync' do
        action = :create
        args = [model, action, anything]
        expect_publish_model(args)
        model.ps_perform_sync(action)
      end

      it 'performs manual update sync' do
        action = :update
        args = [model, action, be_a(Hash)]
        expect_publish_model(args)
        model.ps_perform_sync(action)
      end

      it 'performs with custom data' do
        custom_data = { title: 'custom title' }
        expect_publish(have_attributes(data: custom_data))
        model.ps_perform_sync(:create, custom_data: custom_data)
      end

      it 'includes custom headers' do
        custom_headers = { key: 'custom title' }
        expect_publish(have_attributes(headers: include(custom_headers)))
        model.ps_perform_sync(:create, custom_headers: custom_headers)
      end
    end
  end

  private

  def expect_publish_data(args)
    expect(publisher_klass).to receive(:publish_data).with(*args)
  end

  def expect_publish_model(args)
    expect(publisher_klass).to receive(:publish_model).with(*args)
  end

  def expect_no_publish_model(args)
    expect(publisher_klass).not_to receive(:publish_model).with(*args)
  end

  def expect_publish(args)
    expect(publisher_klass).to receive(:publish).with(*args)
  end
end
