# frozen_string_literal: true

begin
  require 'google/cloud/pubsub'
rescue LoadError # rubocop:disable Lint/SuppressedException
end

module PubSubModelSync
  class ServiceGoogle < ServiceBase
    LISTEN_SETTINGS = { message_ordering: true }.freeze
    TOPIC_SETTINGS = {}.freeze
    SUBSCRIPTION_SETTINGS = { message_ordering: true }.freeze
    attr_accessor :service, :topic, :subscription, :subscriber

    def initialize
      @service = Google::Cloud::Pubsub.new(project: config.project,
                                           credentials: config.credentials)
      @topic = service.topic(config.topic_name) ||
               service.create_topic(config.topic_name, TOPIC_SETTINGS)
      topic.enable_message_ordering!
    end

    def listen_messages
      @subscription = subscribe_to_topic
      @subscriber = subscription.listen(LISTEN_SETTINGS, &method(:process_message))
      log('Listener starting...')
      subscriber.start
      log('Listener started')
      sleep
      subscriber.stop.wait!
      log('Listener stopped')
    end

    # @param payload (PubSubModelSync::Payload)
    def publish(payload)
      topic.publish_async(payload.to_json, message_headers(payload)) do |res|
        raise 'Failed to publish the message.' unless res.succeeded?
      end
    end

    def stop
      log('Listener stopping...')
      subscriber.stop!
    end

    private

    # @param payload (PubSubModelSync::Payload)
    def message_headers(payload)
      {
        SERVICE_KEY => true,
        ordering_key: payload.headers[:ordering_key]
      }.merge(PUBLISH_SETTINGS)
    end

    def subscribe_to_topic
      topic.subscription(config.subscription_key) ||
        topic.subscribe(config.subscription_key, SUBSCRIPTION_SETTINGS)
    end

    def process_message(received_message)
      message = received_message.message
      super(message.data) if message.attributes[SERVICE_KEY]
    ensure
      received_message.acknowledge!
    end
  end
end
