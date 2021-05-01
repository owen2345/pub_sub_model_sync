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
    it 'publishes parent notifications before children notifications' do
      publish_calls = []
      allow(connector).to receive(:publish) do |payload|
        publish_calls << payload.info.merge(payload.headers.slice(:ordering_key))
      end
      user = create_user_with_posts(qty_posts: 4)
      puts "@@@@@@@@@@#{publish_calls.inspect}"
      expect(publish_calls[0]).to eq({ klass: 'PublisherUser', action: :save, ordering_key: "PublisherUser/#{user.id}" })
      expect(publish_calls[1]).to eq({ klass: 'Post', action: :save, ordering_key: "PublisherUser/#{user.id}" })
      expect(publish_calls[2]).to eq({ klass: 'Post', action: :save, ordering_key: "PublisherUser/#{user.id}" })
    end
  end

  private

  # @return (PublisherUser)
  def create_user_with_posts(qty_posts: 2)
    user = mock_publisher_callback(:after_save_commit, { name: 'name'}, method = :new) do
      ps_publish(:save, mapping: %i[id name email])
    end
    qty_posts.times.each { |index| user.posts << Post.new(title: "post #{index}") }
    user.save! && user
  end

  def expect_publish_model(args)
    expect(publisher_klass).to receive(:publish_model).with(*args)
  end
end
