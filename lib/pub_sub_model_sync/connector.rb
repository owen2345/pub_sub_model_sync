# frozen_string_literal: true

require 'google/cloud/pubsub'
module PubSubModelSync
  class Connector
    attr_accessor :service, :topic, :subscription, :config, :subscriber

    def initialize
      @config = PubSubModelSync::Config
      @service = Google::Cloud::Pubsub.new(project: config.project,
                                           credentials: config.credentials)
      @topic = service.topic(config.topic_name) ||
               service.create_topic(config.topic_name)
    end

    def listen_messages
      @subscription = subscribe_to_topic
      @subscriber = subscription.listen(&method(:process_message))
      log('Listener starting...')
      subscriber.start
      log('Listener started')
      sleep
      subscriber.stop.wait!
      log('Listener stopped')
    end

    def stop
      log('Listener stopping...')
      subscriber.stop!
    end

    private

    def subscribe_to_topic
      topic.subscription(config.subscription_name) ||
        topic.subscribe(config.subscription_name)
    end

    def process_message(received_message)
      message = received_message.message
      attrs = message.attributes.symbolize_keys
      return unless attrs[:service_model_sync]

      data = JSON.parse(message.data).symbolize_keys
      PubSubModelSync::MessageProcessor.new(data, attrs).process
    rescue => e # rubocop:disable Style/RescueStandardError
      log("Error processing message: #{[received_message, e.message]}")
    ensure
      received_message.acknowledge!
    end

    def log(msg)
      config.log(msg)
    end
  end
end
