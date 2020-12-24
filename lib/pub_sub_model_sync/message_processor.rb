# frozen_string_literal: true

module PubSubModelSync
  class MessageProcessor < PubSubModelSync::Base
    attr_accessor :payload

    # @param payload (Payload): payload to be delivered
    # @Deprecated: def initialize(data, klass, action)
    def initialize(payload, klass = nil, action = nil)
      @payload = payload
      return if @payload.is_a?(Payload)

      # support for deprecated
      log('Deprecated: Use Payload instead of new(data, klass, action)')
      @payload = PubSubModelSync::Payload.new(payload, { klass: klass, action: action })
    end

    def process
      filter_subscribers.each(&method(:run_subscriber))
    end

    private

    def run_subscriber(subscriber)
      return unless processable?(subscriber)

      subscriber.process!(payload)
      config.on_success_processing.call(payload, subscriber)
      log "processed message with: #{payload}"
    rescue => e
      print_subscriber_error(e)
    end

    def processable?(subscriber)
      cancel = config.on_before_processing.call(payload, subscriber) == :cancel
      log("process message cancelled: #{payload}") if cancel && config.debug
      !cancel
    end

    # @param error (Error)
    def print_subscriber_error(error)
      info = [payload, error.message, error.backtrace]
      res = config.on_error_processing.call(error, payload)
      log("Error processing message: #{info}", :error) if res != :skip_log
    end

    def filter_subscribers
      config.subscribers.select do |subscriber|
        subscriber.settings[:from_klass].to_s == payload.klass.to_s &&
          subscriber.settings[:from_action].to_s == payload.action.to_s
      end
    end
  end
end
