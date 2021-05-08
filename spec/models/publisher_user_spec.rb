# frozen_string_literal: true

RSpec.describe PublisherUser, truncate: true do
  let(:publisher_klass) { PubSubModelSync::MessagePublisher }
  let(:connector) { PubSubModelSync::MessagePublisher.connector }

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

  describe 'when ensuring notifications order' do
    let(:user_data) { { name: 'name', posts_attributes: [{ title: 'P1' }, { title: 'P2' }] } }
    let(:user) do
      mock_publisher_callback([:ps_crud_publish, %i[create update destroy]], user_data) do |action|
        ps_publish(action, mapping: %i[id name email])
      end
    end
    let(:key) { "PublisherUser/#{user.id}" }

    it 'publishes correct ordering when created' do
      calls = capture_notifications { user.save! }
      expect(calls[0]).to include({ klass: 'PublisherUser', action: :create, ordering_key: key, id: user.id })
      expect(calls[1]).to include({ klass: 'Post', action: :create, ordering_key: key, id: user.posts.first.id })
      expect(calls[2]).to include({ klass: 'Post', action: :create, ordering_key: key, id: user.posts.second.id })
    end

    it 'publishes correct ordering when updated' do
      user.save!
      changed_data = { name: 'Changed', posts_attributes: [{ id: user.posts.first.id, title: 'P1 changed' },
                                                           { id: user.posts.second.id, title: 'P2 changed' }] }
      calls = capture_notifications { user.update!(changed_data) }
      expect(calls[0]).to include({ klass: 'PublisherUser', action: :update, ordering_key: key, id: user.id })
      expect(calls[1]).to include({ klass: 'Post', action: :update, ordering_key: key, id: user.posts.first.id })
      expect(calls[2]).to include({ klass: 'Post', action: :update, ordering_key: key, id: user.posts.second.id })
    end

    it 'publishes correct ordering when destroyed' do
      user.save!
      posts_ids = user.posts.pluck(:id)
      calls = capture_notifications { user.destroy! }
      expect(calls[0]).to include({ klass: 'Post', action: :destroy, ordering_key: key, id: posts_ids.first })
      expect(calls[1]).to include({ klass: 'Post', action: :destroy, ordering_key: key, id: posts_ids.second })
      expect(calls[2]).to include({ klass: 'PublisherUser', action: :destroy, ordering_key: key, id: user.id })
    end
  end

  private

  # @return (PublisherUser)
  def capture_notifications(&block)
    calls = []
    allow(connector).to receive(:publish) do |payload|
      calls << payload.info.merge(payload.headers.slice(:ordering_key)).merge(id: payload.data[:id])
    end
    block.call
    calls
  end

  def expect_publish_model(args)
    expect(publisher_klass).to receive(:publish_model).with(*args)
  end
end
