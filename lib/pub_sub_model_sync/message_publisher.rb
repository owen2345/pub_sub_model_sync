# frozen_string_literal: true

module PubSubModelSync
  class MessagePublisher
    class << self
      delegate :publish, to: :connector

      def connector
        @connector ||= PubSubModelSync::Connector.new
      end

      def publish_data(klass, data, action)
        attrs = { klass: klass.to_s, action: action.to_sym }
        publish(data, attrs)
      end

      # @param model: ActiveRecord model
      # @param action: (Sym) Action name
      # @param publisher: (Publisher) Publisher to be used
      def publish_model(model, action, publisher = nil)
        return if model.ps_skip_sync?(action)

        publisher ||= model.class.ps_publisher(action)
        payload = publisher.payload(model, action)
        res_before = model.ps_before_sync(action, payload[:data])
        return if res_before == :cancel

        publish(payload[:data], payload[:attrs])
        model.ps_after_sync(action, payload[:data])
      end

      private

      def log(msg)
        PubSubModelSync::Config.log(msg)
      end
    end
  end
end
