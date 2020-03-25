# frozen_string_literal: true

require 'google/cloud/pubsub'
module PubSubModelSync
  class Connector
    attr_accessor :service
    delegate :listen_messages, :publish, :stop, to: :service

    def initialize
      @service = build_service
    end

    private

    def build_service
      case Config.service_name
      when :google
        PubSubModelSync::ServiceGoogle.new
      when :kafka
        PubSubModelSync::ServiceKafka.new
      else # :rabbit_mq
        PubSubModelSync::ServiceRabbit.new
      end
    end
  end
end
