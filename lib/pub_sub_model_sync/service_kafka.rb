# frozen_string_literal: true

begin
  require 'kafka'
rescue LoadError # rubocop:disable Lint/SuppressedException
end

module PubSubModelSync
  class ServiceKafka < ServiceBase
    cattr_accessor :producer
    attr_accessor :config, :service, :consumer

    def initialize
      @config = PubSubModelSync::Config
      settings = config.kafka_connection
      settings[1][:client_id] ||= config.subscription_key
      @service = Kafka.new(*settings)
    end

    def listen_messages
      log('Listener starting...')
      start_consumer
      consumer.each_message(LISTEN_SETTINGS, &method(:process_message))
    rescue PubSubModelSync::Runner::ShutDown
      log('Listener stopped')
    rescue => e
      log("Error listening message: #{[e.message, e.backtrace]}", :error)
    end

    def publish(payload)
      settings = {
        topic: config.topic_name,
        headers: { SERVICE_KEY => true }
      }.merge(PUBLISH_SETTINGS)
      producer.produce(payload.to_json, settings)
      producer.deliver_messages
    end

    def stop
      log('Listener stopping...')
      consumer.stop
    end

    private

    def start_consumer
      @consumer = service.consumer(group_id: config.subscription_key)
      consumer.subscribe(config.topic_name)
    end

    def producer
      return self.class.producer if self.class.producer

      at_exit { self.class.producer.shutdown }
      self.class.producer = service.producer
    end

    def process_message(message)
      return unless message.headers[SERVICE_KEY]

      super(message.value)
    end
  end
end
