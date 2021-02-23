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
    attr_accessor :config, :service, :topic_names, :channels

    def initialize
      @config = PubSubModelSync::Config
      @service = Bunny.new(*config.bunny_connection)
      @topic_names = Array(config.topic_name || 'model_sync')
      @channels = []
    end

    def listen_messages
      log('Listener starting...')
      subscribe_to_queues { |queue| queue.subscribe(LISTEN_SETTINGS, &method(:process_message)) }
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

    def process_message(_delivery_info, meta_info, payload)
      super(payload) if meta_info[:type] == SERVICE_KEY
    end

    def subscribe_to_queues(&block)
      @channels = []
      topic_names.each do |topic_name|
        subscribe_to_exchange(topic_name) do |channel, exchange|
          queue = channel.queue(config.subscription_key, QUEUE_SETTINGS)
          queue.bind(exchange) # TODO: review missing routing_key
          @channels << channel
          block.call(queue)
        end
      end
    end

    def subscribe_to_exchange(topic_name, &block)
      service.start
      channel = service.create_channel
      exchange = channel.fanout(topic_name)
      block.call(channel, exchange)
    end

    def find_topic_name(payload)
      payload.headers[:topic_name] || topic_names.first
    end

    def deliver_data(payload)
      subscribe_to_exchange(find_topic_name(payload)) do |channel, exchange|
        exchange.publish(payload.to_json, message_settings(payload))

        # Ugly fix: "IO timeout when reading 7 bytes"
        # https://stackoverflow.com/questions/39039129/rabbitmq-timeouterror-io-timeout-when-reading-7-bytes
        channel.close
        service.close
      end
    end
  end
end
