# frozen_string_literal: true

begin
  require 'bunny'
rescue LoadError # rubocop:disable Lint/SuppressedException
end

module PubSubModelSync
  class ServiceRabbit < ServiceBase
    QUEUE_SETTINGS = { durable: true, auto_delete: false }.freeze
    LISTEN_SETTINGS = { manual_ack: true }.freeze
    PUBLISH_SETTINGS = {}.freeze

    # @!attribute topic_names (Array): ['Topic 1', 'Topic 2']
    # @!attribute channels (Array): [Channel1]
    # @!attribute exchanges (Hash<key: Exchange>): {topic_name: Exchange1}
    attr_accessor :service, :topic_names, :channels, :exchanges

    def initialize
      @service = Bunny.new(*config.bunny_connection)
      @topic_names = Array(config.topic_name || 'model_sync')
      @channels = []
      @exchanges = {}
    end

    def listen_messages
      log('Listener starting...')
      subscribe_to_queues do |queue|
        queue.subscribe(LISTEN_SETTINGS) { |info, meta, payload| process_message(queue, info, meta, payload) }
      end
      log('Listener started')
      loop { sleep 5 }
    rescue PubSubModelSync::Runner::ShutDown
      log('Listener stopped')
    rescue => e
      log("Error listening message: #{[e.message, e.backtrace]}", :error)
    end

    def publish(payload)
      qty_retry ||= 0
      deliver_data(payload)
    rescue => e
      if e.is_a?(Timeout::Error) && (qty_retry += 1) <= 2
        log("Error publishing (retrying....): #{e.message}", :error)
        initialize
        retry
      end
      raise
    end

    def stop
      log('Listener stopping...')
      channels.each(&:close)
      service.close
    end

    private

    def message_settings(payload)
      {
        routing_key: payload.headers[:ordering_key],
        type: SERVICE_KEY,
        persistent: true
      }.merge(PUBLISH_SETTINGS)
    end

    def process_message(queue, delivery_info, meta_info, payload)
      super(payload) if meta_info[:type] == SERVICE_KEY
      queue.channel.ack(delivery_info.delivery_tag)
    end

    def subscribe_to_queues(&block)
      @channels = []
      topic_names.each do |topic_name|
        subscribe_to_exchange(topic_name) do |channel, exchange|
          queue = channel.queue(config.subscription_key, QUEUE_SETTINGS)
          queue.bind(exchange)
          @channels << channel
          log("Subscribed to topic: #{topic_name} as #{queue.name}")
          block.call(queue)
        end
      end
    end

    def subscribe_to_exchange(topic_name, &block)
      topic_name = topic_name.to_s
      exchanges[topic_name] ||= begin
        service.start
        channel = service.create_channel
        channel.fanout(topic_name)
      end
      block.call(channel, exchanges[topic_name])
    end

    def deliver_data(payload)
      message_topics = Array(payload.headers[:topic_name] || config.default_topic_name)
      message_topics.each do |topic_name|
        subscribe_to_exchange(topic_name) do |_channel, exchange|
          exchange.publish(encode_payload(payload), message_settings(payload))
        end
      end
    end
  end
end
