# frozen_string_literal: true

RSpec.describe PublisherUser do
  it 'crud publisher settings' do
    settings = PublisherUser2.ps_msync_publisher_settings
    expected_settings = { attrs: %i[name custom_name],
                          as_klass: 'User', id: :custom_id }
    expect(settings).to include expected_settings
  end

  describe 'class messages' do
    describe '.ps_msync_class_publish' do
      let(:action) { :greeting }
      let(:data) { { msg: 'Hello' } }
      it 'default values' do
        args = [described_class.name, data, action]
        expect_publish_data(args)
        described_class.ps_msync_class_publish(data, action: action)
      end
      it 'custom class name' do
        as_klass = 'User'
        args = [as_klass, data, action]
        expect_publish_data(args)
        described_class
          .ps_msync_class_publish(data, action: action, as_klass: as_klass)
      end
    end
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

    it '.destroy' do
      model = described_class.create(name: 'name')
      args = [model, :destroy]
      expect_publish_model(args)
      model.destroy!
    end

    describe 'publish only specified attrs' do
      let(:model) { PublisherUser2.create(name: 'name') }
      after { model.update(name: 'changed name') }
      it 'model attributes (PublisherUser2 limited to name, custom_name)' do
        expected_data = hash_including(:name)
        expected_attrs = hash_including(action: :update)
        expect_publish([expected_data, expected_attrs])
      end
      it 'ability to use methods as attributes' do
        expected_data = hash_including(:custom_name)
        expected_attrs = hash_including(action: :update)
        expect_publish([expected_data, expected_attrs])
      end
    end

    describe 'limit actions (PublisherUser2 is :update only)' do
      it 'when update, then publish message' do
        model = PublisherUser2.create(name: 'name')
        model.name = 'changed name'
        args = [anything, :update]
        expect_publish_model(args)
        model.save!
      end

      it 'when update, able to skip message' do
        model = PublisherUser2.create(name: 'name')
        model.name = 'changed name'
        args = [anything, 'update']
        allow(model).to receive(:ps_msync_skip_for?).and_return(true)
        expect_no_publish_model(args)
        model.save!
      end

      it 'when create, then do not publish' do
        model = PublisherUser2.new(name: 'name')
        args = [anything, 'create']
        expect_no_publish_model(args)
        model.save!
      end
    end
  end

  private

  def expect_publish_data(args)
    expect_any_instance_of(PubSubModelSync::Publisher)
      .to receive(:publish_data).with(*args)
  end

  def expect_publish_model(args)
    expect_any_instance_of(PubSubModelSync::Publisher)
      .to receive(:publish_model).with(*args)
  end

  def expect_no_publish_model(args)
    expect_any_instance_of(PubSubModelSync::Publisher)
      .not_to receive(:publish_model).with(*args)
  end

  def expect_publish(args)
    expect_any_instance_of(PubSubModelSync::Connector)
      .to receive(:publish).with(*args)
  end
end
