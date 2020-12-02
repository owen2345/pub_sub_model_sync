# frozen_string_literal: true

require 'pub_sub_model_sync/payload'
module PubSubModelSync
  class ServiceBase < PubSubModelSync::Base
    SERVICE_KEY = 'service_model_sync'

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

    # @param (String: Json string)
    def process_message(payload_info)
      payload = parse_payload(payload_info)
      log("Received message: #{[payload]}") if config.debug
      PubSubModelSync::MessageProcessor.new(payload).process
    rescue => e
      error = [payload, e.message, e.backtrace]
      log("Error parsing received message: #{error}", :error)
    end

    def parse_payload(payload_info)
      info = JSON.parse(payload_info).deep_symbolize_keys
      ::PubSubModelSync::Payload.new(info[:data], info[:attributes])
    end
  end
end
