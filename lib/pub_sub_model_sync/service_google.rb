# frozen_string_literal: true

begin
  require 'google/cloud/pubsub'
rescue LoadError # rubocop:disable Lint/SuppressedException
end

module PubSubModelSync
  class ServiceGoogle < ServiceBase
    LISTEN_SETTINGS = { message_ordering: true }.freeze
    PUBLISH_SETTINGS = {}.freeze
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
      p_topic_names = Array(payload.headers[:topic_name] || config.default_topic_name)
      message_topics = p_topic_names.map(&method(:find_topic))
      message_topics.each { |topic| publish_to_topic(topic, payload) }
    end

    def stop
      log('Listener stopping...')
      (subscribers || []).each(&:stop!)
    end

    private

    def find_topic(topic_name)
      topic_name = topic_name.to_s
      return topics.values.first unless topic_name.present?

      topics[topic_name] || publish_topics[topic_name] || init_topic(topic_name, only_publish: true)
    end

    def publish_to_topic(topic, payload)
      retries ||= 0
      topic.publish_async(encode_payload(payload), message_headers(payload)) do |res|
        raise StandardError, "Failed to publish the message. #{res.error}" unless res.succeeded?
      end
    rescue Google::Cloud::PubSub::OrderingKeyError => e
      raise if (retries += 1) > 1

      log("Resuming ordering_key and retrying OrderingKeyError for #{payload.headers[:uuid]}: #{e.message}")
      topic.resume_publish(message_headers(payload)[:ordering_key])
      retry
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

    # @return [Array<Subscriber>]
    def subscribe_to_topics
      topics.map do |key, topic|
        subs_name = "#{config.subscription_key}_#{key}"
        subscription = topic.subscription(subs_name) || topic.subscribe(subs_name, **SUBSCRIPTION_SETTINGS)
        subscriber = subscription.listen(**LISTEN_SETTINGS, &method(:process_message))
        subscriber.start
        log("Subscribed to topic: #{topic.name} as: #{subs_name}")
        subscriber
      end
    end

    def process_message(received_message)
      message = received_message.message
      super(message.data) if message.attributes[SERVICE_KEY]
      received_message.acknowledge!
    end
  end
end
