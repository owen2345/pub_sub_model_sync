# frozen_string_literal: true

module PubSubModelSync
  class ServiceBase
    def listen_messages
      raise 'method :listen_messages must be defined in service'
    end

    def publish(_data, _attributes)
      raise 'method :publish must be defined in service'
    end

    def stop
      raise 'method :stop must be defined in service'
    end

    private

    # @param payload (String JSON): '{"data":{},"attributes":{..}}'
    #   refer: PubSubModelSync::Publisher (.publish_model | .publish_data)
    def perform_message(payload)
      data, attrs = parse_message_payload(payload)
      args = [data, attrs[:klass], attrs[:action], attrs]
      PubSubModelSync::MessageProcessor.new(*args).process
    end

    def parse_message_payload(payload)
      message_payload = JSON.parse(payload).symbolize_keys
      data = message_payload[:data].symbolize_keys
      attrs = message_payload[:attributes].symbolize_keys
      [data, attrs]
    end
  end
end
