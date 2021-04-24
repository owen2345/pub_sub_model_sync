# frozen_string_literal: true

RSpec.describe PublisherUser do
  let(:publisher_klass) { PubSubModelSync::MessagePublisher }

  describe 'callbacks' do
    it '.save' do
      expect_publish_model([be_a(described_class), :save, any_args])
      mock_publisher_callback(:after_save_commit, { name: 'name' }, method = :create!) do
        ps_publish(:save, mapping: %i[id name email])
      end
    end

    it '.create' do
      expect_publish_model([be_a(described_class), :create, any_args])
      mock_publisher_callback(:after_create_commit, { name: 'name' }, method = :create!) do
        ps_publish(:create, mapping: %i[id name email])
      end
    end

    it '.update' do
      expect_publish_model([be_a(PublisherUser), :update, any_args])
      model = mock_publisher_callback(:after_update_commit, { name: 'name' }, method = :create!) do
        ps_publish(:update, mapping: %i[id name email])
      end
      model.update!(name: 'changed name')
    end

    it '.destroy' do
      expect_publish_model([be_a(PublisherUser), :destroy, any_args])
      model = mock_publisher_callback(:after_destroy_commit, { name: 'name' }, method = :create!) do
        ps_publish(:destroy, mapping: %i[id])
      end
      model.destroy!
    end

    it 'custom event' do
      expect_publish_model([be_a(PublisherUser), :custom, any_args])
      model = described_class.create!(name: 'sample')
      model.ps_publish(:custom, mapping: %i[id name])
    end

    describe 'when grouping all sub syncs', truncate: true do
      it 'uses the same ordering_key for all syncs' do
        model = mock_publisher_callback(:after_update, { name: 'sample' }, :create!) do
          ps_publish(:update, mapping: %i[id])
        end
        allow(model).to receive(:ps_before_publish) do
          PubSubModelSync::MessagePublisher.publish_data('Test', {}, :changed)
        end
        key = PubSubModelSync::Publisher.ordering_key_for(model)
        expect_publish_with_headers({ ordering_key: key }, times: 2) do
          model.update!(name: 'changed')
        end
      end

      it 'restores parent ordering_key when finished' do
        parent_key = 'parent_key'
        model = mock_publisher_callback(:after_update, { name: 'sample' }, :create!) do
          ps_publish(:update, mapping: %i[id])
        end
        publisher_klass.transaction(parent_key) do
          model.update!(name: 'changed')
          expect(publisher_klass.transaction_key).to eq parent_key
        end
      end

      it 'restores transaction_key when failed' do
        model = mock_publisher_callback(:after_update, { name: 'sample' }, :create!) do
          errors.add(:base, 'error updating')
        end
        model.update(name: 'changed')
        expect(publisher_klass.transaction_key).to be_nil
      end
    end
  end

  private

  def expect_publish_model(args)
    expect(publisher_klass).to receive(:publish_model).with(*args)
  end
end
