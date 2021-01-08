# frozen_string_literal: true

module PubSubModelSync
  class MessagePublisher < PubSubModelSync::Base
    class << self
      def connector
        @connector ||= PubSubModelSync::Connector.new
      end

      def publish_data(klass, data, action)
        payload = PubSubModelSync::Payload.new(data, { klass: klass.to_s, action: action.to_sym })
        publish(payload)
      end

      # @param model: ActiveRecord model
      # @param action: (Sym) Action name
      # @param publisher: (Publisher, optional) Publisher to be used
      def publish_model(model, action, publisher = nil)
        return if model.ps_skip_sync?(action)

        publisher ||= model.class.ps_publisher(action)
        payload = publisher.payload(model, action)
        res_before = model.ps_before_sync(action, payload.data)
        return if res_before == :cancel

        publish(payload)
        model.ps_after_sync(action, payload.data)
      end

      def publish(payload, raise_error: false)
        if config.on_before_publish.call(payload) == :cancel
          log("Publish message cancelled: #{payload}") if config.debug
          return
        end

        log("Publishing message: #{[payload]}")
        connector.publish(payload)
        config.on_after_publish.call(payload)
      rescue => e
        raise_error ? raise : notify_error(e, payload)
      end

      private

      def notify_error(exception, payload)
        info = [payload, exception.message, exception.backtrace]
        res = config.on_error_publish.call(exception, { payload: payload })
        log("Error publishing: #{info}", :error) if res != :skip_log
      end
    end
  end
end
