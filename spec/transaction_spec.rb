# frozen_string_literal: true

RSpec.describe PubSubModelSync::Transaction do
  let(:key) { 'some_key' }
  let(:parent_t) { described_class.new(key) }
  let(:child_t) { parent_t.add_transaction(described_class.new('child_key')) }
  let(:payload) { PubSubModelSync::Payload.new({}, { klass: 'Sample', action: :test }) }
  let(:publisher) { described_class::PUBLISHER_KLASS }

  it 'updates children when adding a sub transaction' do
    expect(parent_t.children).to include(child_t)
  end

  describe 'when delivering notifications' do
    it 'updates parent\'s children' do
      child_t.deliver_all
      expect(parent_t.children).to be_empty
    end

    it 'deliveries all parent\'s notification if exist' do
      expect(parent_t).to receive(:deliver_all)
      child_t.deliver_all
    end

    describe 'when there are no pending transactions' do
      it 'deliveries all enqueued notifications' do
        parent_t.add_payload(payload)
        expect(parent_t).to receive(:deliver_payload).with(payload)
        child_t.deliver_all
      end

      it 'cleans up current transaction' do
        expect(publisher).to receive(:current_transaction=).with(nil)
        child_t.deliver_all
      end
    end

    describe 'when there are pending transactions' do
      before { parent_t.add_transaction(described_class.new('pending_child')) }

      it 'does not clean up current transaction' do
        expect(publisher).not_to receive(:current_transaction=)
        child_t.deliver_all
      end

      it 'does not deliver enqueued notifications' do
        parent_t.add_payload(payload)
        expect(parent_t).not_to receive(:deliver_payload)
        child_t.deliver_all
      end
    end
  end

  describe 'when rolling back' do
    it 'clears all transactions' do
      expect(parent_t).to receive(:rollback)
      child_t.rollback
    end

    it 'cleans up current transaction' do
      expect(publisher).to receive(:current_transaction=).with(nil)
      child_t.rollback
    end
  end
end
