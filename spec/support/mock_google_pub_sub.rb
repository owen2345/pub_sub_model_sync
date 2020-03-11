# frozen_string_literal: true

RSpec.configure do |config|
  config.before(:each) do
    mock_stop = double('Stop', wait!: true)
    mock_subscriber = double('Subscriber', start: true, stop: mock_stop)
    mock_subscription = double('Subscription', listen: mock_subscriber)
    mock_topic = double('Topic', subscription: mock_subscription, publish: true)
    pub_sub_mock = double('Google::Cloud::Pubsub', topic: mock_topic)
    allow(Google::Cloud::Pubsub).to receive(:new).and_return(pub_sub_mock)
  end
end