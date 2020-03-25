# frozen_string_literal: true

begin
  require 'kafka'
rescue LoadError # rubocop:disable Lint/SuppressedException
end

module PubSubModelSync
  class ServiceKafka
    cattr_accessor :producer

    attr_accessor :service, :consumer
    attr_accessor :config
    SERVICE_KEY = 'service_model_sync'
    CONSUMER_GROUP = 'service_model_sync'

    def initialize
      @config = PubSubModelSync::Config
      @service = Kafka.new(*config.kafka_connection)
    end

    def listen_messages
      log('Listener starting...')
      start_consumer
      consumer.each_message(topic: config.topic_name, &method(:process_message))
    rescue PubSubModelSync::Runner::ShutDown
      raise
    rescue => e
      log("Error listening message: #{[e.message, e.backtrace]}", :error)
    end

    def publish(data, attributes)
      log("Publishing: #{[data, attributes]}")
      payload = { data: data, attributes: attributes }
      producer.produce(payload.to_json, message_settings)
      producer.deliver_messages
    rescue => e
      info = [data, attributes, e.message, e.backtrace]
      log("Error publishing: #{info}", :error)
    end

    def stop
      log('Listener stopping...')
      consumer.stop
    end

    private

    def message_settings
      { topic: config.topic_name, partition_key: SERVICE_KEY }
    end

    def start_consumer
      @consumer = service.consumer(group_id: CONSUMER_GROUP)
      consumer.subscribe(config.topic_name)
    end

    def producer
      at_exit { self.class.producer.shutdown }
      self.class.producer ||= service.producer
    end

    def process_message(message)
      return unless message.partition == SERVICE_KEY

      data, attrs = parse_message_payload(message.value)
      args = [data, attrs[:klass], attrs[:action], attrs]
      PubSubModelSync::MessageProcessor.new(*args).process
    rescue => e
      error = [message, e.message, e.backtrace]
      log("Error processing message: #{error}", :error)
    end

    def parse_message_payload(payload)
      message_payload = JSON.parse(payload).symbolize_keys
      data = message_payload[:data].symbolize_keys
      attrs = message_payload[:attributes].symbolize_keys
      [data, attrs]
    end

    def log(msg, kind = :info)
      config.log("Kafka Service ==> #{msg}", kind)
    end
  end
end
