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

    # @!attribute topics (Hash): { key: Topic1, ... }
    attr_accessor :service, :topics, :subscriber

    def initialize
      @service = Google::Cloud::Pubsub.new(project: config.project,
                                           credentials: config.credentials)
      @topics = Array(config.topic_name || 'model_sync').map do |topic_name|
        topic = service.topic(topic_name) || service.create_topic(topic_name, TOPIC_SETTINGS)
        topic.enable_message_ordering!
        [topic_name.to_s, topic]
      end.to_h
    end

    def listen_messages
      log('Listener starting...')
      subscribers = subscribe_to_topics
      log('Listener started')
      sleep
      subscribers.each { |subscriber| subscriber.stop.wait! }
      log('Listener stopped')
    end

    # @param payload (PubSubModelSync::Payload)
    def publish(payload)
      find_topic(payload).publish_async(payload.to_json, message_headers(payload)) do |res|
        raise 'Failed to publish the message.' unless res.succeeded?
      end
    end

    def stop
      log('Listener stopping...')
      subscriber.stop!
    end

    private

    def find_topic(payload)
      topics[payload.headers[:topic_name].to_s] || topics.values.first
    end

    # @param payload (PubSubModelSync::Payload)
    def message_headers(payload)
      {
        SERVICE_KEY => true,
        ordering_key: payload.headers[:ordering_key]
      }.merge(PUBLISH_SETTINGS)
    end

    # @return [Subscriber]
    def subscribe_to_topics
      topics.map do |_k, topic|
        subscription = topic.subscription(config.subscription_key) ||
                       topic.subscribe(config.subscription_key, SUBSCRIPTION_SETTINGS)
        subscriber = subscription.listen(LISTEN_SETTINGS, &method(:process_message))
        subscriber.start
        subscriber
      end
    end

    def process_message(received_message)
      message = received_message.message
      super(message.data) if message.attributes[SERVICE_KEY]
    ensure
      received_message.acknowledge!
    end
  end
end
