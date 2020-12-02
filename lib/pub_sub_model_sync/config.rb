# frozen_string_literal: true

module PubSubModelSync
  class Config
    cattr_accessor(:subscribers) { [] }
    cattr_accessor(:publishers) { [] }
    cattr_accessor(:service_name) { :google }

    # customizable callbacks
    cattr_accessor(:debug) { false }
    cattr_accessor :logger # LoggerInst

    cattr_accessor :on_subscription_success, default: lambda { |_payload, _subscriber| }
    cattr_accessor :on_subscription_error, default: lambda { |_exception, _payload| }
    cattr_accessor :on_before_publish, default: lambda { |_payload| }
    cattr_accessor :on_after_publish, default: lambda { |_payload| }
    cattr_accessor :on_publish_error, default: lambda { |_exception, _payload| }

    # google service
    cattr_accessor :project, :credentials, :topic_name, :subscription_name

    # rabbitmq service
    cattr_accessor :bunny_connection, :queue_name, :topic_name

    # kafka service
    cattr_accessor :kafka_connection, :topic_name

    def self.log(msg, kind = :info)
      msg = "PS_MSYNC ==> #{msg}"
      if logger == :raise_error
        kind == :error ? raise(msg) : puts(msg)
      else
        logger ? logger.send(kind, msg) : puts(msg)
      end
    end
  end
end
