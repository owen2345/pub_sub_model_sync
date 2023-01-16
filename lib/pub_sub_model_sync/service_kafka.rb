# frozen_string_literal: true

begin
  require 'kafka'
rescue LoadError # rubocop:disable Lint/SuppressedException
end

module PubSubModelSync
  class ServiceKafka < ServiceBase
    QTY_WORKERS = 10
    LISTEN_SETTINGS = { automatically_mark_as_processed: false }.freeze
    PUBLISH_SETTINGS = {}.freeze
    PRODUCER_SETTINGS = { delivery_threshold: 200, delivery_interval: 30 }.freeze
    cattr_accessor :producer

    # @!attribute topic_names (Array): ['topic 1', 'topic 2']
    attr_accessor :service, :consumer, :topic_names

    def initialize
      settings = config.kafka_connection
      settings[1][:client_id] ||= config.subscription_key
      @service = Kafka.new(*settings)
      @topic_names = ensure_topics(Array(config.topic_name || 'model_sync'))
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
      message_topics = Array(payload.headers[:topic_name] || config.default_topic_name)
      message_topics.each do |topic_name|
        producer.produce(encode_payload(payload), message_settings(payload, topic_name))
      end
    end

    def stop
      log('Listener stopping...')
      consumer.stop
    end

    private

    def message_settings(payload, topic_name)
      {
        topic: ensure_topics(topic_name),
        partition_key: payload.headers[:ordering_key],
        headers: { SERVICE_KEY => true }
      }.merge(PUBLISH_SETTINGS)
    end

    def start_consumer
      subscription_key = config.subscription_key
      @consumer = service.consumer(group_id: subscription_key)
      topic_names.each do |topic_name|
        log("Subscribed to topic: #{topic_name} as #{subscription_key}")
        consumer.subscribe(topic_name)
      end
    end

    def producer
      return self.class.producer if self.class.producer

      at_exit { self.class.producer.shutdown }
      self.class.producer = service.async_producer(PRODUCER_SETTINGS)
    end

    def process_message(message)
      if message.headers[SERVICE_KEY]
        super(message.value)
      elsif config.debug
        log("Unknown message (#{SERVICE_KEY}): #{[message, message.headers]}")
      end
      consumer.mark_message_as_processed(message)
    end

    # Check topic existence, create if missing topic
    # @param names (Array<String>,String)
    # @return (Array,String) return @param names
    def ensure_topics(names)
      missing_topics = Array(names) - (@known_topics || service.topics)
      missing_topics.each do |name|
        service.create_topic(name)
      end
      @known_topics ||= [] # cache service.topics to reduce verification time
      @known_topics = (@known_topics + Array(names)).uniq
      names
    end
  end
end
