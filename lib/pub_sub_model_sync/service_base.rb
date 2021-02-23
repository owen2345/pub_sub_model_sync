# frozen_string_literal: true

require 'pub_sub_model_sync/payload'
module PubSubModelSync
  class ServiceBase < PubSubModelSync::Base
    SERVICE_KEY = 'service_model_sync'

    def listen_messages
      raise 'method :listen_messages must be defined in service'
    end

    # @param _payload (Payload)
    def publish(_payload)
      raise 'method :publish must be defined in service'
    end

    def stop
      raise 'method :stop must be defined in service'
    end

    private

    # @param (String: Payload in json format)
    def process_message(payload_info)
      retries ||= 0
      payload = parse_payload(payload_info)
      return payload.process unless same_app_message?(payload)

      log("Skipping message from same origin: #{[payload]}") if config.debug
    rescue => e
      retry if can_retry_process_message?(e, payload, retries += 1)
    end

    def can_retry_process_message?(error, payload, retries)
      error_payload = [payload, error.message, error.backtrace]
      if retries == 1
        log("Error while starting to process message (retrying...): #{error_payload}", :error)
        rescue_database_connection if lost_db_connection_err?(error)
      else
        log("Retried 1 time and error persists, exiting...: #{error_payload}", :error)
        Process.exit!(true)
      end
      retries == 1
    end

    def parse_payload(payload_info)
      info = JSON.parse(payload_info).deep_symbolize_keys
      payload = ::PubSubModelSync::Payload.new(info[:data], info[:attributes], info[:headers])
      log("Received message: #{[payload]}") if config.debug
      payload
    end

    # @param payload (Payload)
    def same_app_message?(payload)
      key = payload.headers[:app_key]
      key && key == config.subscription_key
    end

    def lost_db_connection_err?(error)
      return true if error.class.name == 'PG::UnableToSend' # rubocop:disable Style/ClassEqualityComparison

      error.message.match?(/lost connection/i)
    end

    def rescue_database_connection
      log('Lost DB connection. Attempting to reconnect...', :warn)
      ActiveRecord::Base.connection.reconnect!
    rescue
      log('Cannot reconnect to database, exiting...', :error)
      Process.exit!(true)
    end
  end
end
