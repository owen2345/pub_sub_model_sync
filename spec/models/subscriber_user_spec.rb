# frozen_string_literal: true

RSpec.describe SubscriberUser do
  it 'crud publisher settings' do
    settings = described_class.ps_msync_subscriber_settings
    expect(settings).not_to be_nil
  end
end
