# frozen_string_literal: true

require 'active_support/core_ext/module'
module PubSubModelSync
  class Runner
    delegate :preload_listeners, to: :class
    attr_accessor :connector

    def initialize
      @connector = PubSubModelSync::Connector.new
    end

    def run
      at_exit { connector.stop }
      trap_signals!
      preload_listeners
      start_listeners
    end

    def self.preload_listeners
      Rails.application.try(:eager_load!) if defined?(Rails)
      Zeitwerk::Loader.eager_load_all if defined?(Zeitwerk::Loader)
    end

    private

    def start_listeners
      connector.listen_messages
    end

    def trap_signals!
      handler = proc do |signal|
        puts "PS_MSYNC ==> received #{Signal.signame(signal)}"
        exit
      end
      %w[INT QUIT TERM].each { |signal| Signal.trap(signal, handler) }
    end
  end
end
