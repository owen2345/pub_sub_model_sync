# frozen_string_literal: true

begin
  require 'google/cloud/pubsub'
rescue LoadError # rubocop:disable Lint/SuppressedException
end

module PubSubModelSync
  class ServiceGoogle < ServiceBase
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

    def publish(data, attributes)
      log("Publishing message: #{[attributes, data]}")
      payload = { data: data, attributes: attributes }.to_json
      topic.publish(payload, { SERVICE_KEY => true })
    rescue => e
      info = [attributes, data, e.message, e.backtrace]
      log("Error publishing: #{info}", :error)
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
      return unless message.attributes[SERVICE_KEY]

      perform_message(message.data)
    rescue => e
      log("Error processing message: #{[received_message, e.message]}", :error)
    ensure
      received_message.acknowledge!
    end

    def log(msg, kind = :info)
      config.log("Google Service ==> #{msg}", kind)
    end
  end
end
