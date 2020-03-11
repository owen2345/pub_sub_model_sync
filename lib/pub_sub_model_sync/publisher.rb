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

    def publish_model(model, action, attrs, as_class = nil, id = nil)
      klass = as_class || model.class.name
      id_val = model[id || :id]
      attributes = build_attrs(klass, action, id_val)
      data = model.as_json(only: attrs)
      log("Publishing model data: #{[data, attributes]}")
      connector.topic.publish(data.to_json, attributes)
    end

    private

    def build_attrs(klass, action, id = nil)
      {
        class: klass,
        action: action,
        id: id,
        service_model_sync: true
      }
    end

    def log(msg)
      PubSubModelSync::Config.log(msg)
    end
  end
end
