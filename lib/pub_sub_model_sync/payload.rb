# frozen_string_literal: true

module PubSubModelSync
  class Payload
    class MissingInfo < StandardError; end
    attr_reader :data, :info, :headers

    # @param data (Hash: { any value }):
    # @param info (Hash):
    #   klass: (String, required) Notification class name
    #   action: (Symbol, required) Notification action name
    #   mode: (:model|:klass, default :model): :model for instance and :klass for class notifications
    # @param headers (Hash):
    #   key (String): identifier of the payload, default:
    #        <klass/action>: when class message
    #        <klass/action/model.id>: when model message
    #   ordering_key (String): messages with the same key are processed in the same order they
    #     were delivered, default:
    #        <klass>: when class message
    #        <klass/id>: when model message
    #   topic_name (String|Array<String>): Specific topic name to be used when delivering the
    #     message (default Config.topic_name)
    #   forced_ordering_key (String, optional): Will force to use this value as the ordering_key,
    #     even withing transactions. Default nil.
    #   cache (Boolean | Hash, Default false) Cache settings
    #     true: Skip publishing similar payloads
    #     Hash<required: Array<Symbol>>: Same as true and enables payload optimization to exclude
    #       unchanged non important attributes. Sample: { required: %i[id email] }
    #   --- READ ONLY ----
    #   app_key: (string) Subscriber-Key of the application who delivered the notification
    #   internal_key: (String) "<klass>/<action>"
    #   uuid: Unique notification identifier
    def initialize(data, info, headers = {})
      @data = data.deep_symbolize_keys
      @info = info.deep_symbolize_keys
      @headers = headers.deep_symbolize_keys
      build_headers
      validate!
    end

    # @return Hash: payload data
    def to_h
      { data: data.clone, info: info.clone, headers: headers.clone }
    end

    def klass
      info[:klass].to_s
    end

    def action
      info[:action].to_sym
    end

    def mode
      (info[:mode] || :model).to_sym
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
      PubSubModelSync::MessagePublisher.publish!(self)
    end

    # Publish payload to pubsub
    #   (If error will call on_error_publish callback)
    def publish
      PubSubModelSync::MessagePublisher.publish(self)
    end

    # allows to retry publishing a failed payload
    def retry_publish!
      PubSubModelSync::MessagePublisher.connector_publish(self)
    end

    # @param attr_keys (Array<Symbol>) List of attributes to be excluded from payload
    def exclude_data_attrs(attr_keys)
      orig_data = data.clone
      headers[:excluded_attr_keys] = attr_keys.join(',')
      @data = data.except(*attr_keys)
      Config.log("Empty payload after payload optimization (original data: #{[self, orig_data]})") if @data == []
    end

    # Attributes to always be delivered after cache optimization
    def cache_settings
      headers[:cache]
    end

    # convert payload data into Payload
    # @param data [Hash]: payload data (:data, :info, :headers)
    def self.from_payload_data(data)
      data = data.symbolize_keys
      new(data[:data], data[:info] || data[:attributes], data[:headers])
    end

    private

    def build_headers
      headers[:app_key] ||= PubSubModelSync::Config.subscription_key
      headers[:internal_key] ||= [klass, action].join('/')
      headers[:ordering_key] ||= klass
      headers[:uuid] ||= SecureRandom.uuid
    end

    def validate!
      raise MissingInfo if !info[:klass] || !info[:action]
    end
  end
end
