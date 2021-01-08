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

    def retry_error(error_klass, qty: 2, &block)
      @retries ||= 0
      block.call
    rescue error_klass => _e
      (@retries += 1) <= qty ? retry : raise
    end
  end
end
