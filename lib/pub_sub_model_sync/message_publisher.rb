# frozen_string_literal: true

module PubSubModelSync
  class MessagePublisher < PubSubModelSync::Base
    class << self
      def connector
        @connector ||= PubSubModelSync::Connector.new
      end

      # Publishes any value to pubsub
      # @param klass (String): Class name
      # @param data (Hash): Data to be delivered
      # @param action (:symbol): action name
      def publish_data(klass, data, action)
        attrs = { klass: klass.to_s, action: action.to_sym }
        payload = PubSubModelSync::Payload.new(data, attrs)
        publish(payload)
      end

      # Publishes model info to pubsub
      # @param model (ActiveRecord model)
      # @param action (Sym): Action name
      # @param publisher (Publisher, optional): Publisher to be used
      def publish_model(model, action, publisher = nil)
        return if model.ps_skip_sync?(action)

        publisher ||= model.class.ps_publisher(action)
        payload = publisher.payload(model, action)
        res_before = model.ps_before_sync(action, payload.data)
        return if res_before == :cancel

        publish(payload)
        model.ps_after_sync(action, payload.data)
      end

      # Publishes payload to pubsub
      # @attr payload (PubSubModelSync::Payload)
      # Raises error if exist
      def publish!(payload)
        if config.on_before_publish.call(payload) == :cancel
          log("Publish message cancelled: #{payload}") if config.debug
          return
        end

        log("Publishing message: #{[payload]}")
        connector.publish(payload)
        config.on_after_publish.call(payload)
      end

      # Similar to :publish! method
      # Notifies error via :on_error_publish instead of raising error
      def publish(payload)
        publish!(payload)
      rescue => e
        notify_error(e, payload)
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
