# frozen_string_literal: true

module PubSubModelSync
  class MessageProcessor
    attr_accessor :data, :klass, :action, :message_id

    # @param data (Hash): any hash value to deliver
    def initialize(data, klass, action)
      @data = data
      @klass = klass
      @action = action
      @message_id = [klass, action, Time.now.hash].join('-')
    end

    def process
      log "processing message: #{[data, klass, action]}"
      subscribers = filter_subscribers
      return log 'Skipped: No listeners' unless subscribers.any?

      subscribers.each { |subscriber| run_subscriber(subscriber) }
    end

    private

    def run_subscriber(subscriber)
      subscriber.eval_message(data)
      log "processed message for: #{subscriber.info}"
    rescue => e
      log("error message (#{subscriber.info}): #{e.message}", :error)
    end

    def filter_subscribers
      PubSubModelSync::Config.subscribers.select do |subscriber|
        subscriber.settings[:from_klass].to_s == klass.to_s &&
          subscriber.settings[:from_action].to_s == action.to_s
      end
    end

    def log(message, kind = :info)
      PubSubModelSync::Config.log "(ID: #{message_id}) #{message}", kind
    end
  end
end
