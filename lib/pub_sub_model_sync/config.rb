# frozen_string_literal: true

module PubSubModelSync
  class Config
    cattr_accessor(:subscribers) { [] }
    cattr_accessor(:publishers) { [] }
    cattr_accessor(:service_name) { :google }

    # customizable callbacks
    cattr_accessor(:debug) { false }
    cattr_accessor :logger # LoggerInst

    cattr_accessor(:on_before_processing) { ->(_payload, _info) {} } # return :cancel to skip
    cattr_accessor(:on_success_processing) { ->(_payload, _info) {} }
    cattr_accessor(:on_error_processing) { ->(_exception, _info) {} }
    cattr_accessor(:on_before_publish) { ->(_payload) {} } # return :cancel to skip
    cattr_accessor(:on_after_publish) { ->(_payload) {} }
    cattr_accessor(:on_error_publish) { ->(_exception, _info) {} }
    cattr_accessor(:disabled_callback_publisher) { ->(_model, _action) { false } }

    # google service
    cattr_accessor :project, :credentials, :topic_name, :subscription_name

    # rabbitmq service
    cattr_accessor :bunny_connection, :topic_name, :subscription_name

    # kafka service
    cattr_accessor :kafka_connection, :topic_name, :subscription_name

    def self.log(msg, kind = :info)
      msg = "PS_MSYNC ==> #{msg}"
      if logger == :raise_error
        kind == :error ? raise(msg) : puts(msg)
      else
        logger ? logger.send(kind, msg) : puts(msg)
      end
    end

    def self.subscription_key
      subscription_name ||
        (Rails.application.class.parent_name rescue '') # rubocop:disable Style/RescueModifier
    end
  end
end
