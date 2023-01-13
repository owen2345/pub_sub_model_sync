# frozen_string_literal: true

RSpec.describe PubSubModelSync::Transaction do
  let(:key) { 'some_key' }
  let(:root_t) { described_class.new(key) }
  let(:payload) { PubSubModelSync::Payload.new({}, { klass: 'Sample', action: :test }) }
  let(:publisher) { described_class::PUBLISHER_KLASS }

  it 'updates children when adding a sub transaction' do
    child_t = add_transaction
    expect(root_t.children).to include(child_t)
  end

  describe 'when finishing transaction' do
    it 'does not deliver notifications if there are pending sub transactions' do
      add_transaction
      expect(root_t).not_to receive(:deliver_payloads)
      root_t.finish
    end

    it 'cleans up current transaction' do
      expect(publisher).to receive(:current_transaction=).with(nil)
      root_t.finish
    end

    it 'marks as finished' do
      root_t.finish
      expect(root_t.finished).to be_truthy
    end

    describe 'when finishing sub transaction' do
      it 'updates parent\'s children' do
        child_t = add_transaction
        child_t.finish
        expect(root_t.children).to be_empty
      end

      it 'does not deliver root\'s notifications if root not finished yet' do
        child_t = add_transaction
        expect(root_t).not_to receive(:deliver_payloads)
        child_t.finish
      end

      it 'deliveries root\'s notifications if root already finished' do
        child_t = add_transaction
        _finished_before_child = root_t.finish
        expect(root_t).to receive(:deliver_payloads)
        child_t.finish
      end
    end
  end

  describe 'when rolling back' do
    it 'clears all transactions' do
      child_t = add_transaction
      expect(root_t).to receive(:rollback)
      child_t.rollback
    end

    it 'cleans up current transaction' do
      expect(publisher).to receive(:current_transaction=).with(nil)
      root_t.rollback
    end

    it 'clears root\'s notifications' do
      root_t.rollback
      expect(root_t.payloads).to eq([])
    end
  end

  private

  def add_transaction
    root_t.add_transaction(described_class.new(nil))
  end
end
