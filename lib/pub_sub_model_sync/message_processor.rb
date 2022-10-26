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
      subscribers = filter_subscribers
      payload_info = { klass: payload.klass, action: payload.action, mode: payload.mode }
      log("No subscribers found for #{payload_info}", :warn) if config.debug && subscribers.empty?
      subscribers.each(&method(:run_subscriber))
    end

    def process
      process!
    rescue => e
      notify_error(e)
    end

    private

    def run_subscriber(subscriber) # rubocop:disable Metrics/AbcSize
      retries ||= 0
      processor = PubSubModelSync::RunSubscriber.new(subscriber, payload)
      return unless processable?(subscriber)

      log("Processing message #{[subscriber, payload]}...") if config.debug
      processor.call
      res = config.on_success_processing.call(payload, { subscriber: subscriber })
      log "processed message with: #{payload.inspect}" if res != :skip_log
    rescue => e
      retry_process?(e, retries += 1) ? retry : raise(e)
    end

    def processable?(subscriber)
      cancel = config.on_before_processing.call(payload, { subscriber: subscriber }) == :cancel
      log("process message cancelled: #{payload}") if cancel && config.debug
      !cancel
    end

    # @param error (StandardError, Exception)
    def notify_error(error)
      error_msg = 'Error processing message: '
      error_details = [payload, error.message, error.backtrace]
      res = config.on_error_processing.call(error, { payload: payload })
      log("#{error_msg} #{error_details}", :error) if res != :skip_log
    rescue => e
      error_details = [payload, e.message, e.backtrace]
      log("#{error_msg} #{error_details}", :error)
      raise(e)
    end

    # @param error [StandardError]
    def lost_db_connection?(error)
      classes = %w[ActiveRecord::ConnectionTimeoutError PG::Error ActiveRecord::ConnectionNotEstablished]
      classes.include?(error.class.name) ||
        error.message.match?(/Lost connection to MySQL server/i) ||
        error.message.start_with?('PG::ConnectionBad:') ||
        error.message.start_with?('PG::UnableToSend:')
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

    # @return (Array<PubSubModelSync::Subscriber>)
    def filter_subscribers
      config.subscribers.select do |subscriber|
        subscriber.from_klass == payload.klass && subscriber.action == payload.action && payload.mode == subscriber.mode
      end
    end
  end
end
