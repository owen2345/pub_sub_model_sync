# frozen_string_literal: true

module PubSubModelSync
  class Payload
    class MissingInfo < StandardError; end
    attr_reader :data, :settings, :headers

    # @param data (Hash: { any value }):
    # @param settings (Hash: { klass*: string, action*: :sym }):
    # @param headers (Hash):
    #   key (String): identifier of the payload, default:
    #        klass/action: when class message
    #        klass/action/model.id: when model message
    #   ordering_key (String): messages with the same key are processed in the same order they
    #     were delivered, default:
    #        klass: when class message
    #        klass/id: when model message
    #   topic_name (String|Array<String>): Specific topic name to be used when delivering the
    #     message (default first topic)
    #   forced_ordering_key (String, optional): Will force to use this value as the ordering_key,
    #     even withing transactions. Default nil.
    def initialize(data, settings, headers = {})
      @data = data
      @settings = settings
      @headers = headers
      build_headers
      validate!
    end

    # @return Hash: payload data
    def to_h
      { data: data, settings: settings, headers: headers }
    end

    def klass
      settings[:klass].to_s
    end

    def action
      settings[:action]
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
    # @param data [Hash]: payload data (:data, :settings, :headers)
    def self.from_payload_data(data)
      data = data.deep_symbolize_keys
      new(data[:data], data[:settings], data[:headers])
    end

    private

    def build_headers
      headers[:app_key] ||= PubSubModelSync::Config.subscription_key
      headers[:key] ||= [klass, action].join('/')
      headers[:ordering_key] ||= klass
      headers[:uuid] ||= SecureRandom.uuid
    end

    def validate!
      raise MissingInfo if !settings[:klass] || !settings[:action]
    end
  end
end
