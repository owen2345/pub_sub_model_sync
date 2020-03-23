# frozen_string_literal: true

module PubSubModelSync
  class Publisher
    attr_accessor :connector
    def initialize
      @connector = PubSubModelSync::Connector.new
    end

    def publish_data(klass, data, action)
      attributes = self.class.build_attrs(klass, action)
      connector.publish(data, attributes)
    end

    # @param settings (Hash): { attrs: [], as_klass: nil, id: nil }
    def publish_model(model, action, settings = nil)
      settings ||= model.class.ps_publisher_settings
      attributes = build_model_attrs(model, action, settings)
      data = {}
      data = build_model_data(model, settings[:attrs]) if action != 'destroy'
      connector.publish(data.symbolize_keys, attributes)
    end

    def self.build_attrs(klass, action, id = nil)
      {
        klass: klass.to_s,
        action: action.to_sym,
        id: id,
        service_model_sync: true
      }
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
      id_val = model.send(settings[:id] || :id)
      self.class.build_attrs(as_klass, action, id_val)
    end

    def log(msg)
      PubSubModelSync::Config.log(msg)
    end
  end
end
