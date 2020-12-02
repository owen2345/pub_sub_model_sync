# frozen_string_literal: true

begin
  require 'kafka'
rescue LoadError # rubocop:disable Lint/SuppressedException
end

module PubSubModelSync
  class ServiceKafka < ServiceBase
    cattr_accessor :producer

    attr_accessor :service, :consumer
    attr_accessor :config
    CONSUMER_GROUP = 'service_model_sync'

    def initialize
      @config = PubSubModelSync::Config
      @service = Kafka.new(*config.kafka_connection)
    end

    def listen_messages
      log('Listener starting...')
      start_consumer
      consumer.each_message(&method(:process_message))
    rescue PubSubModelSync::Runner::ShutDown
      log('Listener stopped')
    rescue => e
      log("Error listening message: #{[e.message, e.backtrace]}", :error)
    end

    def publish(payload)
      producer.produce(payload.to_json, message_settings)
      producer.deliver_messages
    end

    def stop
      log('Listener stopping...')
      consumer.stop
    end

    private

    def message_settings
      { topic: config.topic_name, headers: { SERVICE_KEY => true } }
    end

    def start_consumer
      @consumer = service.consumer(group_id: CONSUMER_GROUP)
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
