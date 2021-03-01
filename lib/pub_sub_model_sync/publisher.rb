# frozen_string_literal: true

module PubSubModelSync
  class Publisher
    attr_accessor :attrs, :actions, :klass, :as_klass, :headers
    # @return (Hash, default nil): custom data to be delivered instead of parsed_data
    attr_accessor :custom_data

    # @param headers (Hash): refer Payload.headers
    def initialize(attrs, klass, actions = nil, as_klass = nil, headers: {})
      @attrs = attrs
      @klass = klass
      @actions = actions || %i[create update destroy]
      @as_klass = as_klass || klass
      @headers = headers
    end

    # Builds the payload with model information defined for :action (:create|:update|:destroy)
    # @param custom_headers (Hash, default {}): refer Payload.headers
    def payload(model, action, custom_headers: {})
      all_headers = self.class.headers_for(model, action).merge(headers).merge(custom_headers)
      data = custom_data || payload_data(model)
      PubSubModelSync::Payload.new(data, payload_attrs(model, action), all_headers)
    end

    def self.headers_for(model, action)
      key = [model.class.name, action, model.id].join('/')
      { ordering_key: ordering_key_for(model), key: key }
    end

    def self.ordering_key_for(model)
      [model.class.name, model.id || SecureRandom.uuid].join('/')
    end

    private

    def payload_data(model)
      @attrs.map do |prop|
        source, target = prop.to_s.split(':')
        [target || source, model.send(source.to_sym)]
      end.to_h.symbolize_keys
    end

    def payload_attrs(model, action)
      {
        klass: (as_klass || model.class.name).to_s,
        action: action.to_sym
      }
    end
  end
end
