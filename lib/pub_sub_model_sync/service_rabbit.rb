# frozen_string_literal: true

begin
  require 'bunny'
rescue LoadError # rubocop:disable Lint/SuppressedException
end

module PubSubModelSync
  class ServiceRabbit < ServiceBase
    attr_accessor :service, :channel, :queue, :topic
    attr_accessor :config

    def initialize
      @config = PubSubModelSync::Config
      @service = Bunny.new(*config.bunny_connection)
    end

    def listen_messages
      log('Listener starting...')
      subscribe_to_queue
      log('Listener started')
      queue.subscribe(subscribe_settings, &method(:process_message))
      loop { sleep 5 }
    rescue PubSubModelSync::Runner::ShutDown
      raise
    rescue => e
      log("Error listening message: #{[e.message, e.backtrace]}", :error)
    end

    def publish(data, attributes)
      log("Publishing: #{[attributes, data]}")
      deliver_data(data, attributes)
    # TODO: max retry
    rescue Timeout::Error => e
      log("Error publishing (retrying....): #{e.message}", :error)
      initialize
      retry
    rescue => e
      info = [attributes, data, e.message, e.backtrace]
      log("Error publishing: #{info}", :error)
    end

    def stop
      log('Listener stopping...')
      service.close
    end

    private

    def message_settings
      { routing_key: queue.name, type: SERVICE_KEY }
    end

    def subscribe_settings
      { manual_ack: false }
    end

    def process_message(_delivery_info, meta_info, payload)
      return unless meta_info[:type] == SERVICE_KEY

      perform_message(payload)
    rescue => e
      error = [payload, e.message, e.backtrace]
      log("Error processing message: #{error}", :error)
    end

    def subscribe_to_queue
      service.start
      @channel = service.create_channel
      queue_settings = { durable: true, auto_delete: false }
      @queue = channel.queue(config.queue_name, queue_settings)
      subscribe_to_topic
    end

    def subscribe_to_topic
      @topic = channel.topic(config.topic_name)
      queue.bind(topic, routing_key: queue.name)
    end

    def log(msg, kind = :info)
      config.log("Rabbit Service ==> #{msg}", kind)
    end

    def deliver_data(data, attributes)
      subscribe_to_queue
      payload = { data: data, attributes: attributes }
      topic.publish(payload.to_json, message_settings)

      # Ugly fix: "IO timeout when reading 7 bytes"
      # https://stackoverflow.com/questions/39039129/rabbitmq-timeouterror-io-timeout-when-reading-7-bytes
      channel.close
      service.close
    end
  end
end
