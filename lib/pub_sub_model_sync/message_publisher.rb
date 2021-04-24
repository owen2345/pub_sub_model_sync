# frozen_string_literal: true

module PubSubModelSync
  class MessagePublisher < PubSubModelSync::Base
    class << self
      class MissingPublisher < StandardError; end
      attr_accessor :transaction_key

      def connector
        @connector ||= PubSubModelSync::Connector.new
      end

      # Permits to group all payloads with the same ordering_key and be processed in the same order
      #   they are published by the subscribers. Grouping by ordering_key allows us to enable
      #   multiple workers in our Pub/Sub service(s), and still guarantee that related payloads will
      #   be processed in the correct order, despite of the multiple threads. This thanks to the fact
      #   that Pub/Sub services will always send messages with the same `ordering_key` into the same
      #   worker/thread.
      # @!macro transaction_key: (String|Hash<use_first: true>)
      # @param key (@transaction_key) This key will be used as the ordering_key for all payloads
      #     inside this transaction.
      def transaction(key, &block)
        parent_key = init_transaction(key)
        begin
          block.call
        ensure
          end_transaction(parent_key)
        end
      end

      # Starts a new transaction
      # @param key (@transaction_key)
      # @return (String|Hash) returns parent transaction key
      def init_transaction(key)
        parent_key = transaction_key
        self.transaction_key = transaction_key.presence || key
        parent_key
      end

      # @param parent_key (@transaction_key)
      # Restores to the last transaction key
      def end_transaction(parent_key)
        self.transaction_key = parent_key
      end

      # Publishes any value to pubsub
      # @param klass (String): Class name
      # @param data (Hash): Data to be delivered
      # @param action (:symbol): action name
      # @param headers (Hash, optional): header settings (More in Payload.headers)
      # @return Payload
      def publish_data(klass, data, action, headers: {})
        attrs = { klass: klass.to_s, action: action.to_sym }
        payload = PubSubModelSync::Payload.new(data, attrs, headers)
        publish(payload)
      end

      # @param model (ActiveRecord::Base)
      # @see PublishConcern::ps_publish_event
      def publish_model(model, action, data: {}, mapping: [], headers: {})
        return if model.ps_skip_sync?(action)

        publisher = PubSubModelSync::Publisher.new(model, action, data: data, mapping: mapping, headers: headers)
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
        calc_ordering_key(payload)
        forced_ordering_key = payload.headers[:forced_ordering_key]
        payload.headers[:ordering_key] = forced_ordering_key if forced_ordering_key
        cancelled = config.on_before_publish.call(payload) == :cancel
        log("Publish cancelled by config.on_before_publish: #{payload}") if config.debug && cancelled
        !cancelled
      end

      # TODO: to be reviewed
      def calc_ordering_key(payload)
        return unless @transaction_key.present?

        key = @transaction_key
        if @transaction_key.is_a?(Hash)
          @transaction_key[:id] ||= payload.headers[:ordering_key] if @transaction_key[:use_first]
          key = @transaction_key[:id]
        end
        payload.headers[:ordering_key] = key
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
