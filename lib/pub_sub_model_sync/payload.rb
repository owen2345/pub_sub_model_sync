# frozen_string_literal: true

module PubSubModelSync
  class Payload
    class MissingInfo < StandardError; end
    attr_reader :data, :attributes, :headers

    # @param data (Hash: { any value }):
    # @param attributes (Hash: { klass*: string, action*: :sym }):
    # @param headers (Hash: { key?: string, ordering_key?: string, topic_name?: string,
    #   ...any_key?: anything }):
    #   key: identifier of the payload, default:
    #        klass/action: when class message
    #        klass/action/model.id: when model message
    #   ordering_key: messages with the same key are processed in the same order they were delivered
    #        default:
    #        klass: when class message
    #        klass/id: when model message
    #   topic_name: Specific topic name to be used when delivering the message (default first topic)
    def initialize(data, attributes, headers = {})
      @data = data
      @attributes = attributes
      @headers = headers
      build_headers
      validate!
    end

    # @return Hash: payload data
    def to_h
      { data: data, attributes: attributes, headers: headers }
    end

    def klass
      attributes[:klass].to_s
    end

    def action
      attributes[:action]
    end

    # Process payload data
    #   (If error will raise exception and wont call on_error_processing callback)
    def process!
      publisher = PubSubModelSync::MessageProcessor.new(self)
      publisher.process!
    end

    # Process payload data
    #   (If error will call on_error_processing callback)
    def process
      publisher = PubSubModelSync::MessageProcessor.new(self)
      publisher.process
    end

    # Publish payload to pubsub
    #   (If error will raise exception and wont call on_error_publish callback)
    def publish!
      klass = PubSubModelSync::MessagePublisher
      klass.publish!(self)
    end

    # Publish payload to pubsub
    #   (If error will call on_error_publish callback)
    def publish
      klass = PubSubModelSync::MessagePublisher
      klass.publish(self)
    end

    # convert payload data into Payload
    # @param data [Hash]: payload data (:data, :attributes, :headers)
    def self.from_payload_data(data)
      data = data.deep_symbolize_keys
      new(data[:data], data[:attributes], data[:headers])
    end

    private

    def build_headers
      headers[:app_key] ||= PubSubModelSync::Config.subscription_key
      headers[:key] ||= [klass, action].join('/')
      headers[:ordering_key] ||= klass
    end

    def validate!
      raise MissingInfo if !attributes[:klass] || !attributes[:action]
    end
  end
end
