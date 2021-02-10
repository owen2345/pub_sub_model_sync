# frozen_string_literal: true

module PubSubModelSync
  class Payload
    class MissingInfo < StandardError; end
    attr_reader :data, :attributes, :headers

    # @param data (Hash: { any value }):
    # @param attributes (Hash: { klass*: string, action*: :sym }):
    # @param headers (Hash: { key?: string, ...any_key?: anything }):
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
      attributes[:klass]
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
      headers[:uuid] ||= SecureRandom.uuid
      headers[:app_key] ||= PubSubModelSync::Config.subscription_key
      headers[:key] ||= [klass.to_s, action].join('/')
    end

    def validate!
      raise MissingInfo if !attributes[:klass] || !attributes[:action]
    end
  end
end
