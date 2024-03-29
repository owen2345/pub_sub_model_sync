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
      # @param settings (Hash<:headers, :max_buffer>)
      #   @option headers [Hash] Headers to be merged for each payload inside this transaction
      #   @option max_buffer [Integer] Deprecated
      # @param block (Yield) block to be executed
      def transaction(key, settings = {}, &block)
        t = init_transaction(key, settings)
        block.call
        t.finish
      rescue
        t.rollback
        raise
      ensure
        t.clean_publisher
      end

      # Starts a new transaction
      # @param key (String, Nil)
      # @return (Transaction)
      def init_transaction(key, settings = {})
        new_transaction = PubSubModelSync::Transaction.new(key, **settings)
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
        info = { klass: klass.to_s, action: action.to_sym, mode: :klass }
        log("Building payload for: #{info.inspect}") if config.debug
        payload = PubSubModelSync::Payload.new(data, info, headers)
        define_transaction_key(payload)
        publish(payload)
      end

      # @param model (ActiveRecord::Base,PubSubModelSync::PublisherConcern)
      # @param action (Symbol,String @see PublishConcern::ps_publish)
      # @param settings (Hash @see PayloadBuilder.settings)
      def publish_model(model, action, settings = {})
        log("Building payload for: #{[model, action].inspect}") if config.debug
        payload = PubSubModelSync::PayloadBuilder.new(model, action, settings).call
        define_transaction_key(payload)
        transaction(payload.headers[:ordering_key]) do # catch and group all :ps_before_publish syncs
          publish(payload) { model.ps_after_publish(action, payload) } if ensure_model_publish(model, action, payload)
        end
      end

      # Publishes payload to pubsub
      # @param payload (PubSubModelSync::Payload)
      # @return Payload
      # Raises error if exist
      def publish!(payload, &block)
        add_transaction_headers(payload)
        return unless ensure_publish(payload)

        current_transaction ? current_transaction.add_payload(payload) : connector_publish(payload)
        block&.call
        payload
      rescue => e
        print_error(e, payload)
        raise
      end

      # Similar to :publish! method but ignores the error if failed
      # @return Payload
      def publish(payload, &block)
        publish!(payload, &block)
      rescue => e
        config.on_error_publish.call(e, { payload: payload })
      end

      def connector_publish(payload)
        log("Publishing message #{[payload.uuid]}...") if config.debug
        connector.publish(payload)
        log("Published message: #{[payload]}")
        config.on_after_publish.call(payload)
      end

      private

      def ensure_publish(payload)
        cache_klass = PubSubModelSync::PayloadCacheOptimizer
        cancelled_cache = payload.cache_settings ? cache_klass.new(payload).call == :already_sent : false
        cancelled = cancelled_cache || config.on_before_publish.call(payload) == :cancel
        log_msg = "Publish cancelled by #{cancelled_cache ? 'cache checker' : 'config.on_before_publish'}: #{[payload]}"
        log(log_msg) if config.debug && cancelled
        !cancelled
      end

      def add_transaction_headers(payload)
        force_key = payload.headers[:forced_ordering_key]
        key = force_key || current_transaction&.key || payload.headers[:ordering_key]
        key = payload.headers[:ordering_key] if force_key == true
        payload.headers[:ordering_key] = key
        payload.headers.merge!(current_transaction.headers) if current_transaction
      end

      def ensure_model_publish(model, action, payload)
        res_before = model.ps_before_publish(action, payload)
        cancelled = res_before == :cancel
        log("Publish cancelled by model.ps_before_publish: #{[payload]}") if config.debug && cancelled
        !cancelled
      end

      # @param error (StandardError, Exception)
      def print_error(error, payload)
        error_msg = 'Error publishing:'
        error_details = [payload, error.message, error.backtrace]
        log("#{error_msg} #{error_details}", :error)
      end

      def define_transaction_key(payload)
        current_transaction&.key ||= payload.headers[:ordering_key]
      end
    end
  end
end
