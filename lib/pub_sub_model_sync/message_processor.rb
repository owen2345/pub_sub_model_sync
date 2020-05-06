# frozen_string_literal: true

module PubSubModelSync
  class MessageProcessor
    attr_accessor :data, :klass, :action

    # @param data (Hash): any hash value to deliver
    def initialize(data, klass, action)
      @data = data
      @klass = klass
      @action = action
    end

    def process
      subscribers = filter_subscribers
      subscribers.each { |subscriber| run_subscriber(subscriber) }
    end

    private

    def run_subscriber(subscriber)
      subscriber.eval_message(data)
      log "processed message with: #{[klass, action, data]}"
    rescue => e
      info = [klass, action, data, e.message, e.backtrace]
      log("error processing message: #{info}", :error)
    end

    def filter_subscribers
      PubSubModelSync::Config.subscribers.select do |subscriber|
        subscriber.settings[:from_klass].to_s == klass.to_s &&
          subscriber.settings[:from_action].to_s == action.to_s
      end
    end

    def log(message, kind = :info)
      PubSubModelSync::Config.log message, kind
    end
  end
end
