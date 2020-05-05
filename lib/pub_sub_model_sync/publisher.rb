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

    def payload(model, action)
      { data: payload_data(model, attrs), attrs: payload_attrs(model, action) }
    end

    private

    def payload_data(model, attrs)
      source_props = attrs.map { |prop| prop.to_s.split(':').first }
      data = model.as_json(only: source_props, methods: source_props)
      aliased_props = attrs.select { |prop| prop.to_s.include?(':') }
      aliased_props.each do |prop|
        source, target = prop.to_s.split(':')
        data[target] = data.delete(source)
      end
      data.symbolize_keys
    end

    def payload_attrs(model, action)
      { klass: (as_klass || model.class.name).to_s, action: action.to_sym }
    end
  end
end
