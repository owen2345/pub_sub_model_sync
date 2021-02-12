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
      source_props = @attrs.map { |prop| prop.to_s.split(':').first }
      data = model.as_json(only: source_props, methods: source_props)
      aliased_props = @attrs.select { |prop| prop.to_s.include?(':') }
      aliased_props.each do |prop|
        source, target = prop.to_s.split(':')
        data[target] = data.delete(source)
      end
      data.symbolize_keys
    end

    def payload_attrs(model, action)
      {
        klass: (as_klass || model.class.name).to_s,
        action: action.to_sym
      }
    end

    def payload_headers(model, action)
      headers = {
        ordering_key: model.ps_transaction_key(action),
        key: [model.class.name, action, model.id].join('/')
      }
      headers.merge!(model.ps_payload_headers(action))
      headers
    end
  end
end
