# frozen_string_literal: true

module PubSubModelSync
  class PayloadCacheOptimizer < PubSubModelSync::Base
    # Optimizes payload data to deliver only the required ones and the changed ones and thus avoid
    #   delivering unnecessary notifications.
    #   Uses Rails.cache to retrieve previous delivered data.
    attr_reader :payload, :required_attrs, :cache_key

    # @param payload (Payload)
    def initialize(payload)
      @payload = payload
      @cache_key = "pubsub/#{payload.headers[:internal_key]}/#{payload.headers[:topic_name]}"
    end

    # @return (:already_sent|Payload)
    def call
      backup_data = payload.data.clone
      return payload if cache_disabled?
      return :already_sent if previous_payload_data == payload.data

      optimize_payload if optimization_allowed?
      Rails.cache.write(cache_key, backup_data, expires_in: 1.week)
      payload
    end

    private

    def optimization_allowed?
      previous_payload_data && payload.cache_settings.is_a?(Hash)
    end

    def cache_disabled?
      res = config.skip_cache || Rails.cache.nil?
      log("Skipping cache, it was disabled: #{[payload.uuid]}") if res && debug?
      res
    end

    def previous_payload_data
      @previous_payload_data ||= Rails.cache.read(cache_key)
    end

    def optimize_payload # rubocop:disable Metrics/AbcSize
      changed_keys = Hash[(payload.data.to_a - previous_payload_data.to_a)].keys.map(&:to_sym)
      required_keys = payload.cache_settings[:required].map(&:to_sym)
      invalid_keys = payload.data.keys - (changed_keys + required_keys)
      log("Excluding non changed attributes: #{invalid_keys} from: #{payload.uuid}") if debug?
      payload.exclude_data_attrs(invalid_keys)
    end
  end
end
