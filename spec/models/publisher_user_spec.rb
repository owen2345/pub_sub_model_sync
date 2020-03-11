# frozen_string_literal: true

RSpec.describe PublisherUser do
  it 'crud publisher settings' do
    settings = described_class.ps_msync_publisher_settings
    expect(settings).not_to be_nil
  end

  describe 'callbacks' do
    let(:publisher) { PubSubModelSync::Publisher.new }
    before do
      allow(described_class)
        .to receive(:ps_msync_publisher).and_return(publisher)
    end
    it '.create' do
      model = described_class.new(name: 'name')
      args = [be_a(model.class), 'create']
      expect(publisher).to receive(:publish_model).with(*args)
      model.save!
    end

    it '.update' do
      model = described_class.create(name: 'name')
      model.name = 'Changed'
      args = [model, 'update']
      expect(publisher).to receive(:publish_model).with(*args)
      model.save!
    end

    it '.destroy' do
      model = described_class.create(name: 'name')
      args = [model, 'destroy']
      expect(publisher).to receive(:publish_model).with(*args)
      model.destroy!
    end

    describe 'limit to update action only' do
      it 'when update, then publish message' do
        model = PublisherUser2.create(name: 'name')
        args = [anything, 'update']
        expect(publisher).not_to receive(:publish_model).with(*args)
        model.save!
      end
      it 'when create, then do not publish' do
        model = PublisherUser2.new(name: 'name')
        expect(publisher).not_to receive(:publish_model)
        model.save!
      end
    end
  end
end
