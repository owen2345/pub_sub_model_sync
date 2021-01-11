# frozen_string_literal: true

begin
  require 'google/cloud/pubsub'
rescue LoadError # rubocop:disable Lint/SuppressedException
end

module PubSubModelSync
  class ServiceGoogle < ServiceBase
    LISTEN_SETTINGS = { threads: { callback: 1 } }.freeze
    SUBSCRIPTION_SETTINGS = { message_ordering: true }.freeze
    attr_accessor :service, :topic, :subscription, :subscriber

    def initialize
      @service = Google::Cloud::Pubsub.new(project: config.project,
                                           credentials: config.credentials)
      @topic = service.topic(config.topic_name) ||
               service.create_topic(config.topic_name)
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

    def publish(payload)
      topic.publish(payload.to_json, { SERVICE_KEY => true }.merge(PUBLISH_SETTINGS))
    end

    def stop
      log('Listener stopping...')
      subscriber.stop!
    end

    private

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
