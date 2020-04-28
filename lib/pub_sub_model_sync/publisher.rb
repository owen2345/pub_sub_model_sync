# frozen_string_literal: true

module PubSubModelSync
  class Publisher
    attr_accessor :connector
    delegate :publish, to: :connector

    def initialize
      @connector = PubSubModelSync::Connector.new
    end

    def publish_data(klass, data, action)
      attributes = self.class.build_attrs(klass, action)
      publish(data, attributes)
    end

    # @param custom_settings (Hash): { attrs: [], as_klass: nil }
    def publish_model(model, action, custom_settings = {})
      return if model.ps_skip_sync?(action)

      settings = model.class.ps_publisher(action).merge(custom_settings)
      attributes = build_model_attrs(model, action, settings)
      data = build_model_data(model, settings[:attrs])
      res_before = model.ps_before_sync(action, data)
      return if res_before == :cancel

      publish(data.symbolize_keys, attributes)
      model.ps_after_sync(action, data)
    end

    def self.build_attrs(klass, action)
      { klass: klass.to_s, action: action.to_sym }
    end

    private

    def build_model_data(model, model_props)
      source_props = model_props.map { |prop| prop.to_s.split(':').first }
      data = model.as_json(only: source_props, methods: source_props)
      aliased_props = model_props.select { |prop| prop.to_s.include?(':') }
      aliased_props.each do |prop|
        source, target = prop.to_s.split(':')
        data[target] = data.delete(source)
      end
      data.symbolize_keys
    end

    def build_model_attrs(model, action, settings)
      as_klass = (settings[:as_klass] || model.class.name).to_s
      self.class.build_attrs(as_klass, action)
    end

    def log(msg)
      PubSubModelSync::Config.log(msg)
    end
  end
end
