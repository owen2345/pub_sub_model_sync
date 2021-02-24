# frozen_string_literal: true

module PubSubModelSync
  class Publisher
    attr_accessor :attrs, :actions, :klass, :as_klass

    def initialize(attrs, klass, actions = nil, as_klass = nil)
      @attrs = attrs
      @klass = klass
      @actions = actions || %i[create update destroy]
      @as_klass = as_klass || klass
    end

    # Builds the payload with model information defined for :action (:create|:update|:destroy)
    def payload(model, action)
      headers = payload_headers(model, action)
      PubSubModelSync::Payload.new(payload_data(model), payload_attrs(model, action), headers)
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
