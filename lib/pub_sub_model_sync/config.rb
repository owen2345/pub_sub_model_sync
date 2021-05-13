# frozen_string_literal: true

module PubSubModelSync
  class Config
    cattr_accessor(:subscribers) { [] }
    cattr_accessor(:service_name) { :google }

    # customizable callbacks
    cattr_accessor(:debug) { false }
    cattr_accessor :logger # LoggerInst
    cattr_accessor(:transactions_use_buffer) { true }

    cattr_accessor(:on_before_processing) { ->(_payload, _info) {} } # return :cancel to skip
    cattr_accessor(:on_success_processing) { ->(_payload, _info) {} }
    cattr_accessor(:on_error_processing) { ->(_exception, _info) {} }
    cattr_accessor(:on_before_publish) { ->(_payload) {} } # return :cancel to skip
    cattr_accessor(:on_after_publish) { ->(_payload) {} }
    cattr_accessor(:on_error_publish) { ->(_exception, _info) {} }

    # google service
    cattr_accessor :project, :credentials, :topic_name, :subscription_name, :default_topic_name

    # rabbitmq service
    cattr_accessor :bunny_connection, :topic_name, :subscription_name, :default_topic_name

    # kafka service
    cattr_accessor :kafka_connection, :topic_name, :subscription_name, :default_topic_name

    def self.log(msg, kind = :info)
      msg = "PS_MSYNC ==> #{msg}"
      if logger == :raise_error
        kind == :error ? raise(msg) : puts(msg)
      else
        logger ? logger.send(kind, msg) : puts(msg)
      end
    end

    def self.subscription_key
      klass = Rails.application.class
      app_name = klass.respond_to?(:module_parent_name) ? klass.module_parent_name : klass.parent_name
      subscription_name || app_name
    end

    class << self
      alias default_topic_name_old default_topic_name

      def default_topic_name
        default_topic_name_old || Array(topic_name).first
      end
    end
  end
end
