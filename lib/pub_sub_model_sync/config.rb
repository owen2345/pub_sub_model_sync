# frozen_string_literal: true

module PubSubModelSync
  class Config
    cattr_accessor :listeners, default: []
    cattr_accessor :service_name, default: :google
    cattr_accessor :logger

    # google service
    cattr_accessor :project, :credentials, :topic_name, :subscription_name

    # rabbitmq service
    cattr_accessor :bunny_connection, :queue_name, :topic_name

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
