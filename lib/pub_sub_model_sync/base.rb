# frozen_string_literal: true

module PubSubModelSync
  class Base
    delegate :config, :log, to: self

    private

    def self.config
      PubSubModelSync::Config
    end

    def self.log(message, kind = :info)
      config.log message, kind
    end
  end
end
