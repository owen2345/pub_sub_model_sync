# frozen_string_literal: true

module PubSubModelSync
  class Transaction < Base
    PUBLISHER_KLASS = PubSubModelSync::MessagePublisher
    attr_accessor :key, :payloads, :use_buffer, :parent, :children

    # @param key (String|nil) Transaction key, if empty will use the ordering_key from first payload
    # @param use_buffer (Boolean, default: true) If false, payloads are delivered immediately
    #   (no way to cancel/rollback if transaction failed)
    def initialize(key, use_buffer: config.transactions_use_buffer)
      @key = key
      @use_buffer = use_buffer
      @children = []
      @payloads = []
    end

    # @param payload (Payload)
    def add_payload(payload)
      use_buffer ? payloads << payload : deliver_payload(payload)
    end

    def deliver_all
      if parent
        parent.children = parent.children.reject { |t| t == self }
        parent.deliver_all
      end
      payloads.each(&method(:deliver_payload)) if children.empty?
      clean_publisher
    end

    def add_transaction(transaction)
      transaction.parent = self
      children << transaction
      transaction
    end

    def rollback
      log("rollback #{children.count} notifications", :warn) if children.any? && debug?
      self.children = []
      parent&.rollback
      clean_publisher
    end

    def clean_publisher
      PUBLISHER_KLASS.current_transaction = nil if !parent && children.empty?
    end

    private

    def deliver_payload(payload)
      PUBLISHER_KLASS.connector_publish(payload)
    rescue => e
      PUBLISHER_KLASS.send(:notify_error, e, payload)
    end
  end
end
