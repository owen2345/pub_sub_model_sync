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
    # @!attribute publish_topics (Hash): { key: Topic1, ... }
    attr_accessor :service, :topics, :subscribers, :publish_topics

    def initialize
      @service = Google::Cloud::Pubsub.new(project: config.project,
                                           credentials: config.credentials)
      Array(config.topic_name || 'model_sync').each(&method(:init_topic))
    end

    def listen_messages
      log('Listener starting...')
      @subscribers = subscribe_to_topics
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
      subscribers.each(&:stop!)
    end

    private

    def find_topic(payload)
      topic_name = payload.headers[:topic_name].to_s
      return topics.values.first unless topic_name.present?

      topics[topic_name] || publish_topics[topic_name] || init_topic(topic_name, only_publish: true)
    end

    # @param only_publish (Boolean): if false is used to listen and publish messages
    # @return (Topic): returns created or loaded topic
    def init_topic(topic_name, only_publish: false)
      topic_name = topic_name.to_s
      @topics ||= {}
      @publish_topics ||= {}
      topic = service.topic(topic_name) || service.create_topic(topic_name, TOPIC_SETTINGS)
      topic.enable_message_ordering!
      publish_topics[topic_name] = topic if only_publish
      topics[topic_name] = topic unless only_publish
      topic
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
