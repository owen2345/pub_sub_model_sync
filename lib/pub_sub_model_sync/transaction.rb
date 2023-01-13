# frozen_string_literal: true

module PubSubModelSync
  class Transaction < Base
    PUBLISHER_KLASS = PubSubModelSync::MessagePublisher
    attr_accessor :key, :payloads, :max_buffer, :root, :children, :finished, :headers

    # @param key (String,Nil) Transaction key, if empty will use the ordering_key from first payload
    # @param max_buffer (Integer) Once this quantity of notifications is reached, then all notifications
    #   will immediately be delivered.
    #   Note: There is no way to rollback delivered notifications if current transaction fails
    def initialize(key, max_buffer: config.transactions_max_buffer, headers: {})
      @key = key
      @max_buffer = max_buffer
      @children = []
      @payloads = []
      @headers = headers
    end

    # @param payload (Payload)
    # TODO: remove buffer (already managed by pubsub services when running with config.async = true)
    def add_payload(payload)
      payloads << payload
      deliver_payloads
    end

    def finish # rubocop:disable Metrics/AbcSize
      if root
        root.children = root.children.reject { |t| t == self }
        root.deliver_all if root.finished && root.children.empty?
      end
      self.finished = true
      deliver_all if children.empty?
    end

    def add_transaction(transaction)
      transaction.root = self
      children << transaction
      transaction
    end

    def rollback
      self.children = []
      root&.rollback
      clean_publisher
    end

    def clean_publisher
      PUBLISHER_KLASS.current_transaction = nil if !root && children.empty?
    end

    def deliver_all
      deliver_payloads
      clean_publisher
    end

    private

    def deliver_payloads
      payloads.each(&method(:deliver_payload))
      self.payloads = []
    end

    def deliver_payload(payload)
      PUBLISHER_KLASS.connector_publish(payload)
    end
  end
end
