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

    # @param errors (Array(Class|String))
    def retry_error(errors, qty: 2, &block)
      retries ||= 0
      block.call
    rescue => e
      retries += 1
      res = errors.find { |e_type| match_error?(e, e_type) }
      raise if !res || retries > qty

      sleep(qty * 0.1) && retry
    end

    private

    # @param error (Exception)
    # @param error_type (Class|String)
    def match_error?(error, error_type)
      error_type.is_a?(String) ? error.message.include?(error_type) : error.is_a?(error_type)
    end
  end
end
