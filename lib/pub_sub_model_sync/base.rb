# frozen_string_literal: true

module PubSubModelSync
  class Base
    delegate :config, :log, to: self

    class << self
      def config
        PubSubModelSync::Config
      end

      def log(message, kind = :info)
        config.log message, kind
      end
    end
  end
end
