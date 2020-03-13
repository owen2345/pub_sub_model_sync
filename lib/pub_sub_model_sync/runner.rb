# frozen_string_literal: true

require 'active_support/core_ext/module'
module PubSubModelSync
  class Runner
    class ShutDown < StandardError; end
    attr_accessor :connector

    def initialize
      @connector = PubSubModelSync::Connector.new
    end

    def run
      trap_signals!
      preload_framework!
      start_listeners
    rescue ShutDown
      connector.stop
    end

    private

    def start_listeners
      connector.listen_messages
    end

    def trap_signals!
      handler = proc do |signal|
        puts "received #{Signal.signame(signal)}"
        raise ShutDown
      end
      %w[INT QUIT TERM].each { |signal| Signal.trap(signal, handler) }
    end

    def preload_framework!
      Rails.application.try(:eager_load!) if defined?(Rails)
      Zeitwerk::Loader.eager_load_all if defined?(Zeitwerk::Loader)
    end
  end
end
