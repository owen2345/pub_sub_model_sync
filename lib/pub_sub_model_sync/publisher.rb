# frozen_string_literal: true

module PubSubModelSync
  class Publisher < PubSubModelSync::Base
    attr_accessor :model, :action, :data, :mapping, :headers, :as_klass

    # @param model (ActiveRecord::Base)
    # @param action (@see PublishConcern::ps_publish)
    # @param settings (@see PublishConcern::ps_publish): { data:, mapping:, headers:, as_klass: }
    def initialize(model, action, settings = {})
      @model = model
      @action = action
      @data = settings[:data] || {}
      @mapping = settings[:mapping] || []
      @headers = settings[:headers] || {}
      @as_klass = settings[:as_klass] || model.class.name
    end

    # @return (Payload)
    def payload
      values = compute_value(data)
      values = mapping_data.merge(values)
      PubSubModelSync::Payload.new(values, settings_data, headers_data)
    end

    def self.ordering_key_for(model)
      [model.class.name, model.id || SecureRandom.uuid].join('/')
    end

    private

    def headers_data
      klass_name = model.class.name
      key = [klass_name, action, model.id || SecureRandom.uuid].join('/')
      def_data = { ordering_key: self.class.ordering_key_for(model), key: key }
      def_data.merge(compute_value(headers))
    end

    def compute_value(value)
      res = value
      res = model.send(value, action) if value.is_a?(Symbol) # method name
      res = value.call(model, action) if value.is_a?(Proc)
      res
    end

    def settings_data
      { klass: as_klass, action: action }
    end

    def mapping_data
      mapping.map do |prop|
        source, target = prop.to_s.split(':')
        [target || source, model.send(source.to_sym)]
      end.to_h.symbolize_keys
    end
  end
end
