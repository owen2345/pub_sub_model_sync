# frozen_string_literal: true

module PubSubModelSync
  class MessagePublisher < PubSubModelSync::Base
    class << self
      attr_accessor :transaction_key

      def connector
        @connector ||= PubSubModelSync::Connector.new
      end

      # Permits to group all payloads with the same ordering_key and be processed in the same order
      #   they are published by the subscribers
      # @param key (String): This key will be used as the ordering_key for all payload
      #     inside this transaction.
      def transaction(key, &block)
        old_key = init_transaction(key)
        begin
          block.call
        ensure
          end_transaction(old_key)
        end
      end

      # Starts a news transaction
      # @return (String) returns old transaction key
      def init_transaction(key)
        old_key = transaction_key
        self.transaction_key = transaction_key.presence || key
        old_key
      end

      # Restores to the last transaction key
      def end_transaction(old_key)
        self.transaction_key = old_key
      end

      # Publishes any value to pubsub
      # @param klass (String): Class name
      # @param data (Hash): Data to be delivered
      # @param action (:symbol): action name
      # @param headers (Hash, optional): header settings (More in Payload.headers)
      # @return Payload
      def publish_data(klass, data, action, headers = {})
        attrs = { klass: klass.to_s, action: action.to_sym }
        payload = PubSubModelSync::Payload.new(data, attrs, headers)
        publish(payload)
      end

      # Publishes model info to pubsub
      # @param model (ActiveRecord model)
      # @param action (Sym): Action name
      # @param publisher (Publisher, optional): Publisher to be used
      # @return Payload
      def publish_model(model, action, publisher = nil)
        return if model.ps_skip_sync?(action)

        publisher ||= model.class.ps_publisher(action)
        payload = publisher.payload(model, action)
        transaction(payload.headers[:ordering_key]) do # catch and group all :ps_before_sync syncs
          publish(payload) { model.ps_after_sync(action, payload.data) } if ensure_model_publish(model, action, payload)
        end
      end

      # Publishes payload to pubsub
      # @param payload (PubSubModelSync::Payload)
      # @return Payload
      # Raises error if exist
      def publish!(payload, &block)
        return unless ensure_publish(payload)

        log("Publishing message: #{[payload]}")
        connector.publish(payload)
        config.on_after_publish.call(payload)
        block&.call
        payload
      end

      # Similar to :publish! method
      # Notifies error via :on_error_publish instead of raising error
      # @return Payload
      def publish(payload, &block)
        publish!(payload, &block)
      rescue => e
        notify_error(e, payload)
      end

      private

      def ensure_publish(payload)
        payload.headers[:ordering_key] = @transaction_key if @transaction_key.present?
        cancelled = config.on_before_publish.call(payload) == :cancel
        log("Publish cancelled by config.on_before_publish: #{payload}") if config.debug && cancelled
        !cancelled
      end

      def ensure_model_publish(model, action, payload)
        res_before = model.ps_before_sync(action, payload.data)
        cancelled = res_before == :cancel
        log("Publish cancelled by model.ps_before_sync: #{payload}") if config.debug && cancelled
        !cancelled
      end

      def notify_error(exception, payload)
        info = [payload, exception.message, exception.backtrace]
        res = config.on_error_publish.call(exception, { payload: payload })
        log("Error publishing: #{info}", :error) if res != :skip_log
      end
    end
  end
end
