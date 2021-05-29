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

    def process!
      filter_subscribers.each(&method(:run_subscriber))
    end

    def process
      retries ||= 0
      process!
    rescue => e
      retry_process?(e, retries += 1) ? retry : notify_error(e)
    end

    private

    def run_subscriber(subscriber)
      processor = PubSubModelSync::RunSubscriber.new(subscriber, payload)
      return unless processable?(subscriber)

      processor.call
      res = config.on_success_processing.call(payload, { subscriber: subscriber })
      log "processed message with: #{payload.inspect}" if res != :skip_log
    end

    def processable?(subscriber)
      cancel = config.on_before_processing.call(payload, { subscriber: subscriber }) == :cancel
      log("process message cancelled: #{payload}") if cancel && config.debug
      !cancel
    end

    # @param error (StandardError)
    def notify_error(error)
      info = [payload, error.message, error.backtrace]
      res = config.on_error_processing.call(error, { payload: payload })
      log("Error processing message: #{info}", :error) if res != :skip_log
    end

    def lost_db_connection?(error)
      connection_lost_classes = %w[ActiveRecord::ConnectionTimeoutError PG::UnableToSend]
      connection_lost_classes.include?(error.class.name) || error.message.match?(/lost connection/i)
    end

    def retry_process?(error, retries) # rubocop:disable Metrics/MethodLength
      error_payload = [payload, error.message, error.backtrace]
      return false unless lost_db_connection?(error)

      if retries <= 5
        sleep(retries)
        log("Error processing message: (retrying #{retries}/5): #{error_payload}", :error)
        ActiveRecord::Base.connection.reconnect! rescue nil # rubocop:disable Style/RescueModifier
        true
      else
        log("Retried 5 times and error persists, exiting...: #{error_payload}", :error)
        Process.exit!(true)
      end
    end

    def filter_subscribers
      config.subscribers.select do |subscriber|
        subscriber.from_klass == payload.klass && subscriber.action == payload.action && payload.mode == subscriber.mode
      end
    end
  end
end
