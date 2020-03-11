# frozen_string_literal: true

module PubSubModelSync
  class Publisher
    attr_accessor :connector
    def initialize
      @connector = PubSubModelSync::Connector.new
    end

    def publish_data(klass, data, action)
      attributes = build_attrs(klass, action)
      log("Publishing data: #{[data, attributes]}")
      connector.topic.publish(data.to_json, attributes)
    end

    def publish_model(model, action)
      crud_settings = model.class.ps_msync_publisher_settings
      attributes = build_model_attrs(model, action, crud_settings)
      data = {}
      data = model.as_json(only: crud_settings[:attrs]) if action != 'destroy'
      log("Publishing model data: #{[data, attributes]}")
      connector.topic.publish(data.to_json, attributes)
    end

    private

    def build_model_attrs(model, action, crud_settings)
      as_class = (crud_settings[:as_class] || model.class.name).to_s
      id_val = model.send(crud_settings[:id] || :id)
      build_attrs(as_class, action, id_val)
    end

    def build_attrs(klass, action, id = nil)
      {
        class: klass.to_s,
        action: action.to_s,
        id: id,
        service_model_sync: true
      }
    end

    def log(msg)
      PubSubModelSync::Config.log(msg)
    end
  end
end
