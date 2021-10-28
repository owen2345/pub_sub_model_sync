# frozen_string_literal: true

module PubSubModelSync
  class PayloadBuilder < PubSubModelSync::Base
    attr_accessor :model, :action, :data, :mapping, :headers, :as_klass

    # @param model (ActiveRecord::Base,PubSubModelSync::PublisherConcern)
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
    def call
      values = compute_value(data)
      values = self.class.parse_mapping_for(model, mapping).merge(values)
      PubSubModelSync::Payload.new(values, settings_data, headers_data)
    end

    def self.ordering_key_for(model)
      [model.class.name, model.id || SecureRandom.uuid].join('/')
    end

    # @param model (ActiveRecord::Base)
    # @param mapping (@see PublishConcern::ps_publish -> mapping)
    # @return (Hash) Hash with the corresponding values for each attribute
    # Sample: parse_mapping_for(my_model, %w[id name:full_name])
    #         ==> { id: 10, full_name: 'model.name value' }
    def self.parse_mapping_for(model, mapping)
      mapping.map do |prop|
        source, target = prop.to_s.split(':')
        [target || source, model.send(source.to_sym)]
      end.to_h.symbolize_keys
    end

    private

    def headers_data
      klass_name = model.class.name
      internal_key = [klass_name, action, model.id || SecureRandom.uuid].join('/')
      def_data = { ordering_key: self.class.ordering_key_for(model), internal_key: internal_key }
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
  end
end
