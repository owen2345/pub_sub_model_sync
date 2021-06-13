# frozen_string_literal: true

require 'pub_sub_model_sync/payload'
module PubSubModelSync
  class ServiceBase < PubSubModelSync::Base
    SERVICE_KEY = 'service_model_sync'

    def listen_messages
      raise NoMethodError, 'method :listen_messages must be defined in service'
    end

    # @param _payload (Payload)
    def publish(_payload)
      raise NoMethodError, 'method :publish must be defined in service'
    end

    def stop
      raise NoMethodError, 'method :stop must be defined in service'
    end

    private

    # @param payload (Payload)
    # @return (String): Json Format
    def encode_payload(payload)
      data = payload.to_h
      not_important_keys = %i[ordering_key topic_name forced_ordering_key]
      reduce_payload_size = !config.debug
      data[:headers].except!(*not_important_keys) if reduce_payload_size
      data.to_json
    end

    # @param (String: Payload in json format)
    def process_message(payload_info)
      payload = decode_payload(payload_info)
      return payload.process unless same_app_message?(payload)

      log("Skipping message from same origin: #{[payload]}") if config.debug
    rescue => e
      error_payload = [payload, e.message, e.backtrace]
      log("Error while starting to process a message: #{error_payload}", :error)
    end

    # @return Payload
    def decode_payload(payload_info)
      payload = ::PubSubModelSync::Payload.from_payload_data(JSON.parse(payload_info))
      log("Received message: #{[payload]}") if config.debug
      payload
    end

    # @param payload (Payload)
    def same_app_message?(payload)
      key = payload.headers[:app_key]
      key && key == config.subscription_key
    end
  end
end
