# frozen_string_literal: true

module PubSubModelSync
  class Config
    cattr_accessor :listeners, default: []
    cattr_accessor :project, :credentials, :topic_name, :subscription_name
    cattr_accessor :logger
    def self.log(msg, kind = :info)
      msg = "PS_MSYNC ==> #{msg}"
      logger ? logger.send(kind, msg) : puts(msg)
    end
  end
end
