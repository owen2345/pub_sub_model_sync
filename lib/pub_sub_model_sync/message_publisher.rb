# frozen_string_literal: true

module PubSubModelSync
  class MessagePublisher < PubSubModelSync::Base
    class << self
      class MissingPublisher < StandardError; end
      attr_accessor :current_transaction

      def connector
        @connector ||= PubSubModelSync::Connector.new
      end

      # Permits to group all payloads with the same ordering_key and be processed in the same order
      #   they are published by the subscribers. Grouping by ordering_key allows us to enable
      #   multiple workers in our Pub/Sub service(s), and still guarantee that related payloads will
      #   be processed in the correct order, despite of the multiple threads. This thanks to the fact
      #   that Pub/Sub services will always send messages with the same `ordering_key` into the same
      #   worker/thread.
      # @see Transaction.new(...)
      # @param key (String|Nil)
      # @param block (Yield) block to be executed
      def transaction(key, settings = {}, &block)
        t = init_transaction(key, settings)
        block.call
        t.deliver_all
      rescue
        t.rollback
        raise
      ensure
        t.clean_publisher
      end

      # Starts a new transaction
      # @param key (@transaction_key)
      # @return (Transaction)
      def init_transaction(key, settings = {})
        new_transaction = PubSubModelSync::Transaction.new(key, settings)
        if current_transaction
          current_transaction.add_transaction(new_transaction)
        else
          self.current_transaction = new_transaction
        end
        new_transaction
      end

      # Publishes a class level notification via pubsub
      # @refer PublisherConcern.ps_class_publish
      # @return Payload
      def publish_data(klass, data, action, headers: {})
        attrs = { klass: klass.to_s, action: action.to_sym, mode: :klass }
        payload = PubSubModelSync::Payload.new(data, attrs, headers)
        publish(payload)
      end

      # @param model (ActiveRecord::Base)
      # @param action (Symbol: @see PublishConcern::ps_publish)
      # @param settings (Hash: @see Publisher.new.settings)
      def publish_model(model, action, settings = {})
        return if model.ps_skip_publish?(action)

        publisher = PubSubModelSync::Publisher.new(model, action, settings)
        payload = publisher.payload

        transaction(payload.headers[:ordering_key]) do # catch and group all :ps_before_publish syncs
          publish(payload) { model.ps_after_publish(action, payload) } if ensure_model_publish(model, action, payload)
        end
      end

      # Publishes payload to pubsub
      # @param payload (PubSubModelSync::Payload)
      # @return Payload
      # Raises error if exist
      def publish!(payload, &block)
        payload.headers[:ordering_key] = ordering_key_for(payload)
        return unless ensure_publish(payload)

        current_transaction ? current_transaction.add_payload(payload) : connector_publish(payload)
        block&.call
        payload
      end

      def connector_publish(payload)
        connector.publish(payload)
        log("Published message: #{[payload]}")
        config.on_after_publish.call(payload)
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
        cancelled = config.on_before_publish.call(payload) == :cancel
        log("Publish cancelled by config.on_before_publish: #{payload}") if config.debug && cancelled
        !cancelled
      end

      def ordering_key_for(payload)
        current_transaction&.key ||= payload.headers[:ordering_key]
        payload.headers[:forced_ordering_key] || current_transaction&.key || payload.headers[:ordering_key]
      end

      def ensure_model_publish(model, action, payload)
        res_before = model.ps_before_publish(action, payload)
        cancelled = res_before == :cancel
        log("Publish cancelled by model.ps_before_publish: #{payload}") if config.debug && cancelled
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
