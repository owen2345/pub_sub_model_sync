# frozen_string_literal: true

begin
  require 'kafka'
rescue LoadError # rubocop:disable Lint/SuppressedException
end

module PubSubModelSync
  class ServiceKafka < ServiceBase
    QTY_WORKERS = 10
    LISTEN_SETTINGS = {}.freeze
    PUBLISH_SETTINGS = {}.freeze
    PRODUCER_SETTINGS = {}.freeze
    cattr_accessor :producer

    # @!attribute topic_names (Array): ['topic 1', 'topic 2']
    attr_accessor :config, :service, :consumer, :timeout, :topic_names

    def initialize
      @config = PubSubModelSync::Config
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
      @counter ||= 0
      @counter += 1
      producer.produce(payload.to_json, message_settings(payload))
      stop_timeout
    end

    def stop
      log('Listener stopping...')
      consumer.stop
    end

    private

    def message_settings(payload)
      {
        topic: ensure_topics(payload.headers[:topic_name] || topic_names.first),
        partition_key: payload.headers[:ordering_key],
        headers: { SERVICE_KEY => true }
      }.merge(PUBLISH_SETTINGS)
    end

    def deliver_messages
      producer.deliver_messages
      producer.shutdown
    end

    def stop_timeout
      timeout.exit if timeout&.alive?
    end

    def await(seconds, &block)
      @timeout = Thread.new do
        sleep seconds
        block.call
      end
    end

    def start_consumer
      @consumer = service.consumer(group_id: config.subscription_key)
      topic_names.each { |topic_name| consumer.subscribe(topic_name) }
    end

    def producer
      return self.class.producer if self.class.producer

      at_exit { self.class.producer.shutdown }
      self.class.producer = service.async_producer(PRODUCER_SETTINGS)
    end

    def process_message(message)
      super(message.value) if message.headers[SERVICE_KEY]
    end

    # Check topic existence, create if missing topic
    # @param names (Array<String>|String)
    # @return (Array|String) return @param names
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
