# frozen_string_literal: true

require 'pub_sub_model_sync/payload'
module PubSubModelSync
  class ServiceBase < PubSubModelSync::Base
    SERVICE_KEY = 'service_model_sync'
    PUBLISH_SETTINGS = {}.freeze
    LISTEN_SETTINGS = {}.freeze

    def listen_messages
      raise 'method :listen_messages must be defined in service'
    end

    # @param _payload (Payload)
    def publish(_payload)
      raise 'method :publish must be defined in service'
    end

    def stop
      raise 'method :stop must be defined in service'
    end

    private

    # @param (String: Payload in json format)
    def process_message(payload_info)
      payload = parse_payload(payload_info)
      log("Received message: #{[payload]}") if config.debug
      if same_app_message?(payload)
        log("Skip message from same origin: #{[payload]}") if config.debug
      else
        payload.process
      end
    rescue => e
      error = [payload, e.message, e.backtrace]
      log("Error parsing received message: #{error}", :error)
    end

    def parse_payload(payload_info)
      info = JSON.parse(payload_info).deep_symbolize_keys
      ::PubSubModelSync::Payload.new(info[:data], info[:attributes], info[:headers])
    end

    # @param payload (Payload)
    def same_app_message?(payload)
      key = payload.headers[:app_key]
      key && key == config.subscription_key
    end

    def rescue_database_connection
      ActiveRecord::Base.connection.reconnect!
    rescue => e
      log("Cannot reconnect to database, exiting...", :error)
      Process.exit!(true)
    end
  end
end
